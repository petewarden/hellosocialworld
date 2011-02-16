HelloSocialWorld
================

This is the equivalent of a 'Hello world' example, but for the basic functionality you need to
implement a modern, socially-connected site. It's designed to be a minimal scaffold that you can
easily insert your own application logic and styling into, while it handles authenticating users
and allowing them to share your content on Twitter and Facebook. It's written in Ruby using the 
Sinatra web framework.

# What it does

- Users sign in using either a Twitter or Facebook account.

- Once signed in, either an existing User database record is found, or a new one is created.

- This record has custom application data for each user. In our case, it's just a favorite color.

- Signed in users can edit this color preference

- They can also tweet or wall post directly from our site

# How to install

- Ensure you have Ruby and [RubyGems](http://docs.rubygems.org/read/chapter/3) installed.

- `$> cd Downloads/hellosocialworld/`

- `$> bundle install --without production`

- `$> sudo gem install heroku`

- `$> heroku create ` your app's name, eg 'hellosocialworld_petewarden' (but it must be unique)

- Edit apikeys.rb to add your own keys, after creating apps on Twitter and Facebook

- `$> git push heroku master`

- Visit the site yourappname.heroku.com to see if you can log in

- If nothing shows up, run `$> heroku logs -n 100` to look at the error logs

# Design

- To simplify the code and the user interface, there's no way to link Twitter and Facebook 
accounts. The same person logging in via a different service is treated as a different user.

- There's no email verification or other traditional account creation process. It's assumed that
the Twitter or Facebook sign-in process is all that's needed.

- Only Facebook and Twitter logins are supported. It should be easy enough to add additional
services if needed, but this combination is enough for my purposes.

# Credits

The code for the application is comparatively short thanks to the hard work of these projects
that provide great functionality as pre-packaged gems:

- [Sinatra](http://www.sinatrarb.com/) - Elegant and lightweight web framework
- [OmniAuth](https://github.com/intridea/omniauth) - Flexible and comprehensive authentication system
- [DataMapper](http://datamapper.org/) - [Occasionally maddening](http://www.drmaciver.com/2010/04/datamapper-is-inherently-broken/), but very clean and easy persistent database storage
- [twitter_oauth](https://github.com/moomerman/twitter_oauth) - Solid library for calling the Twitter API 
- [rack/csrf](https://github.com/baldowl/rack_csrf) - A simple way of guarding against CSRF attacks
- [fb_graph](https://github.com/nov/fb_graph) - A good Facebook API library

Drop me an email at [pete@petewarden.com](mailto:pete@petewarden.com) with any questions, bug
reports or suggestions.

Follow me on Twitter - [@petewarden](http://twitter.com/petewarden)