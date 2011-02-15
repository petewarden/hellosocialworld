# You'll need to fill these out with your own credentials

# Go to http://dev.twitter.com/apps/new to get Twitter keys
TWITTER_CONSUMER_KEY = ''
TWITTER_CONSUMER_SECRET = ''

# Go to http://developers.facebook.com/setup/ to get Facebook keys
FACEBOOK_APPLICATION_ID = ''
FACEBOOK_APPLICATION_SECRET = ''

if TWITTER_CONSUMER_KEY == ''
  raise 'You need to add your own API keys to apikeys.rb'
end