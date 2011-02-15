#***********************************************************************************
#
# This is a minimal but complete example, demonstrating how to build a simple site
# that uses Twitter or Facebook for authentication and sharing. It's designed as a
# scaffold around which you can associate your own application's data with users,
# give them access to edit the objects they own, and then publish them to the world,
# both on your site and as tweets or wall posts.
#
# (C) Pete Warden <pete@petewarden.com> - http://petewarden.typepad.com
# This code is freely reusable with no restrictions
# See http://github.com/petewarden/hellosocialworld/ for source
#
#***********************************************************************************

require 'rubygems' if RUBY_VERSION < '1.9'
require 'sinatra'
require 'omniauth'
require 'openid/store/filesystem'
require 'apikeys'
require 'data_mapper'
require 'twitter_oauth'
require 'rack/csrf'
require 'fb_graph'

# This is the model we'll be using to store data about our users. It assumes that
# there's only a single account associated with a particular user. For my app
# that's all I need, and the has_many relationship required to merge accounts
# would introduce a lot of complexity to the interface and the logic.
class User
  include DataMapper::Resource
  # The key for users is of the form '<id>@<provider', eg '12345@twitter', so that
  # the combination is unique, even if two providers use the same id number.
  property :full_id,        String, :key => true, :unique_index => true
  
  # We pull all of these properties out of the information returned from Facebook or
  # Twitter. They're updated on every subsequent login.
  property :provider,           String
  property :name,               String
  property :location,           String
  property :email,              String
  property :profile_link,       Text
  property :portrait_link,      Text
  
  # These are the OAuth tokens we can use to make API calls after login
  property :credential_token,   Text
  property :credential_secret,  Text

  # This is a JSON-encoded version of the full structure returned from the provider
  # The exact contents vary between Twitter and Facebook.
  property :full_user_info,     Text
  
  # If this is set to true, then this user will be able to edit anyone's color
  # preferences. For this example, it's set to false on user creation, and can only
  # be enabled if you go in and hand-edit the database.
  property :is_administrator,   Boolean
  
  # The time when the user first logged in and we created this record.
  property :created_at,         DateTime
  
  # All these subsequent properties are the meat of our application, the things that
  # our users 'own', and that we require a login to edit. In a real application,
  # these might be items like blog posts, stored as separate objects in the database
  # with a has_many relationship from this User model. For simplicity's sake though,
  # all this example lets users do is publish their favorite control.
  property :favorite_color,     String
  property :edited_at,          DateTime
end

# You can see query information if you turn on the logging.
#DataMapper::Logger.new(STDOUT, :debug)
#DataMapper::Model.raise_on_save_failure = true

# Use either the default Heroku database, or a local sqlite one for development 
DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/development.db")

# This pulls in any changes we've made to the data definitions since the last time
DataMapper.auto_upgrade!

# See http://emilloer.com/2011/01/15/preventing-csrf-in-sinatra/ for why we need to
# protect our forms against CSRF with this middleware.
configure do
# It would be nice to avoid session-fixation attacks with the line below, but
# unfortunately Heroku fails without a stack trace with this enabled. Related to(?)
# http://stackoverflow.com/questions/2187767/racksessioncookie-error-using-sinatra-thin-rails-and-rackcascade
#  use Rack::Session::Cookie, :secret => 'change_me'
  use Rack::Csrf, :raise => true, :skip => ['POST:/auth/*', 'GET:/auth/*']
end

# Creates the routes and controller code to handle the login mechanics for these
# two providers. There's more available here - https://github.com/intridea/omniauth
use OmniAuth::Builder do
  provider :twitter, TWITTER_CONSUMER_KEY, TWITTER_CONSUMER_SECRET 
  provider :facebook, FACEBOOK_APPLICATION_ID, FACEBOOK_APPLICATION_SECRET, {:scope => 'publish_stream,email'}
end

# Pulls in some helper functions, and aliases escape_html() to h()
helpers do
  include Rack::Utils
  alias_method :h, :escape_html

  # A couple of wrappers for the CSRF elements we need to add to all forms
  def csrf_token
    Rack::Csrf.csrf_token(env)
  end

  def csrf_tag
    Rack::Csrf.csrf_tag(env)
  end
end

# This example uses sessions to store the base login information. This has some
# drawbacks, notably when you want to load balance across machines, and you need to
# take care to avoid session fixation attacks, but it's still a decent approach.
enable :sessions
enable :run

# This function returns information about the current authenticated user, if there
# is one.
def get_user
  if !session[:user_id]
    # There's no user information stored in the session
    user = nil
  else
    # We found a user who'd previously logged in, so pull up their information
    full_id = session[:user_id]
    user = User.first(:full_id => full_id)

    # It shouldn't be possible to get here without creating a User record in the
    # database, but just in case, check and redirect to an error page if so.
    if !user
      redirect '/auth/failure'
      user = nil
    end
  end
  
  return user
end

# Checks to make sure that there's a matching, logged-in user
def verify_permissions(required_full_id)

  # Check for a logged-in user
  user = get_user()

  # If there's no logged-in user, immediately bail
  if !user
    halt 403, 'You need to be logged in to do this'
  end
  
  # Check to see if the user owns this object, or if they're a 'super user'
  user_full_id = user.full_id
  is_administrator = user.is_administrator
  
  # If they're not the owner or an administrator, return early
  if (user_full_id != required_full_id) && (!is_administrator)
    halt 403, 'You don\'t have permission to do this'
  end

  return user
end

# Creates an object you can use to call the Twitter API
def get_twitter_client(user)

  client = TwitterOAuth::Client.new(
    :consumer_key => TWITTER_CONSUMER_KEY,
    :consumer_secret => TWITTER_CONSUMER_SECRET,
    :token => user.credential_token, 
    :secret => user.credential_secret
  )

end

# Returns a simple form to share a message with friends on Facebook or Twitter
def get_sharing_html(user, message)

  provider = user.provider

  if provider == 'twitter'
    <<-HTML
    <form method="POST" action="/share/twitter">Share on Twitter: 
    <input type="text" name="message" size="70" value="#{h(message)}"/>
    <input type="submit" value="Tweet"/>
    #{csrf_tag}
    </form>
    HTML
  elsif provider == 'facebook'
    <<-HTML
    <form method="POST" action="/share/facebook">Share on Facebook: 
    <input type="text" name="message" size="70" value="#{h(message)}"/>
    <input type="submit" value="Post"/>
    #{csrf_tag}
    </form>
    HTML
  end

end

# **************************************************************************
# Start of the controller methods that handle page requests
# **************************************************************************

# The main page. We'll provide login options, and display a list of the most
# recently updated favorite colors.
get '/' do

  # Check for a logged-in user
  user = get_user()

  # If there's no stored information, then ask the user to sign in
  if !user
      <<-HTML
      <a href='/auth/twitter'>Sign in with Twitter</a>
      <br/>
      <a href='/auth/facebook'>Sign in with Facebook</a>
      <br/>
      HTML
  else      
      # Use the stored information to construct a personalized welcome for the user
      full_id = user.full_id
      provider = user.provider
      name = user.name
      location = user.location
      profile_link = user.profile_link
      portrait_link = user.portrait_link
      favorite_color = user.favorite_color
      
      # Create the components based on what information is available
      if profile_link
        profile_html = '<a href="'+profile_link+'">'+name+'</a>'
      else
        profile_html = name
      end

      if portrait_link
        portrait_html = '<img src="'+portrait_link+'"/><br/>'
      else
        portrait_html = ''
      end      

      if location
        location_html = ' at ' + location
      else
        location_html = ''
      end

      sharing_html = get_sharing_html(user, 'My favorite color is '+favorite_color+'! Thanks http://example.com')

      # In a real application, most html would actually be created by erb templates.
      <<-HTML
      #{portrait_html}
      You are #{profile_html}#{location_html}, signed in through #{provider}
      <br/>
      Your favorite color is #{h(favorite_color)} <a href='/edit/#{full_id}'>Edit</a>
      <br/>
      #{sharing_html}
      <a href='/auth/logout'>Sign out</a>
      <br/>
      HTML
      
  end
end

# Gets called by OmniAuth once the external login process is done. We're handed
# information about the user that we'll then store.
get '/auth/:name/callback' do

  # This is the parent container for all the information about the user
  auth = request.env['omniauth.auth']

  # Pull out what we need to construct the unique key for the user
  provider = auth['provider']
  uid = auth['uid']
  full_id = uid + '@' + provider

  # Do we already have a record for this user?
  user = User.first(:full_id => full_id)
  if !user
    # If not, then create a new one
    user = User.new( {
      :full_id => full_id,
      :provider => provider,
      :created_at => Time.now,
      :is_administrator => false,
      :favorite_color => 'Blue',
      :edited_at => Time.now
    })
  end

  # Grab any authorization tokens needed for later API calls
  user.credential_token = auth['credentials']['token']
  user.credential_secret = auth['credentials']['secret']
  
  # For the user's information, either fill in for the first time, or overwrite
  # older values
  user_info = auth['user_info']
  user.name = user_info['name']
  user.location = user_info['location']
  user.email = user_info['email']

  # Try to figure out the profile and portrait URLs, if they're available
  if provider == 'twitter'
    user.profile_link = 'http://twitter.com/' + user_info['nickname']
    user.portrait_link = user_info['image']
  elsif provider == 'facebook'
    user.profile_link = user_info['urls']['Facebook']
    user.portrait_link = 'http://graph.facebook.com/'+uid+'/picture'
  else
    user.profile_link = nil
    user.portrait_link = nil
  end    
    
  # Store off a full copy of all the information the provider gave us
  user.full_user_info = user_info.to_json()

  # Store the record in the database
  if !user.save
    # This is horrible, but the exception mechanism doesn't log enough data 
    # See http://www.drmaciver.com/2010/04/datamapper-is-inherently-broken/ 
    user.errors.each do |e|
      puts e
    end
  end
  # Mark this user as logged in
  session[:user_id] = full_id  

  # If we've got it recorded, send the user back to the page they came from,
  # otherwise just to the main page
  redirect request.env['omniauth.origin'] || '/'
end

# Gets called either directly by OmniAuth if there's a problem with the provider's
# login process, or from the application if it runs into an unexpected login issue.
get '/auth/failure' do
  # Make sure we destroy the session so that the user is not marked as logged in.
  session.clear
  <<-HTML
  Something went wrong with the authorization process
  <br/>
  <a href="/">Home</a>
  HTML
end

# Called when the user explicitly wants to log out
get '/auth/logout' do
  # Destroying the session logs out the user
  session.clear
  redirect '/'
end

# The interface we're using to edit the user's favorite color
get '/edit/:full_id' do

  # The id to test against is pulled from the URL
  object_full_id = params[:full_id]

  # Make sure we have permission to edit, and get the user
  user = verify_permissions(object_full_id)

  # This form does a POST to the current URL, including the message and a CSRF token
  <<-HTML
  <form method="POST" action="">Your favorite color is 
  <input type="text" name="favorite_color" value="#{h(user.favorite_color)}"/>
  <input type="submit" value="Update"/>
  #{csrf_tag}
  </form>
  HTML

end

# Called when the user enters an update and submits the form
post '/edit/:full_id' do

  # The id to test against is pulled from the URL
  object_full_id = params[:full_id]

  # Make sure we have permission to edit, and get the user
  user = verify_permissions(object_full_id)

  # Update with the new favorite color
  user.favorite_color = params[:favorite_color]
  user.save

  # It worked, so show a short confirmation
  <<-HTML
  Your favorite color is now #{h(user.favorite_color)}
  <br/>
  <a href="/">Home</a>
  HTML

end

# Called when the user enters an update and submits the form
post '/share/:provider' do

  # Check for a logged-in user
  user = get_user()

  # If there's no logged-in user, immediately bail
  if !user
    halt 403, 'You need to be logged in to do this'
  end

  # We only support a single provider per user, so if there's a mismatch, abort
  provider = params[:provider]
  if provider != user.provider
    halt 500, 'Mismatch between the expected and logged-in providers'
  end
  
  # Pull out the text that was passed in
  message = params[:message]
  
  # Each of the providers has custom code to publish the message
  if provider == 'twitter'

    twitter_client = get_twitter_client(user)
    update_result = twitter_client.update(message)
    status_id = update_result['id_str']
    screen_name = update_result['user']['screen_name']
    tweet_url = 'http://twitter.com/'+screen_name+'/status/'+status_id

    <<-HTML
    <a href="#{tweet_url}">#{h(message)}</a> posted to Twitter
    <br/>
    <a href="/">Home</a>
    HTML
  elsif provider == 'facebook'

    facebook_user = FbGraph::User.me(user.credential_token)
    post = facebook_user.feed!(
      :message => message
    )

    <<-HTML
    <a href="http://facebook.com/profile.php">#{h(message)}</a> posted to Facebook
    <br/>
    <a href="/">Home</a>
    HTML
  end

end