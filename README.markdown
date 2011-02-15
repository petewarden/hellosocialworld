
Edit apikeys.rb
bundle install --without production
sudo gem install heroku
heroku create <your app's name, eg 'hellosocialworld_petewarden'>
git push heroku master
<visit site>
heroku logs -n 100