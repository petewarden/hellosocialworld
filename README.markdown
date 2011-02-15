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

- Edit apikeys.rb

- bundle install --without production

- sudo gem install heroku

- heroku create <your app's name, eg 'hellosocialworld_petewarden'>

- git push heroku master

- <visit site>

- heroku logs -n 100