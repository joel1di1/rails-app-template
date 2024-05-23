# this is a rails template

# slim
gem 'slim-rails'


gem_group :development, :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'shoulda-matchers', require: false
  gem 'simplecov', require: false
  gem 'simplecov_json_formatter', require: false
  gem 'timecop', require: false
end

gem_group :development do
  gem 'ruby-lsp-rspec', require: false
  gem 'rubocop', require: false
  gem 'rubocop-rspec', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rails_config', require: false
end

# add omniauth gem
gem 'omniauth'

installed_auth_providers = []

# ask if we want to install any provider
if yes?("Do you want to install any omniauth provider?")
  loop do
    provider = ask("Which provider do you want to install? (google, github, facebook, twitter), leave blank to skip")
    break if provider.empty?

    installed_auth_providers << provider
  end
end

# install asked providers
installed_auth_providers.each do |provider|
  case provider
  when "google"
    gem 'omniauth-google-oauth2'
  when "facebook"
    gem 'omniauth-facebook'
  when "twitter"
    gem 'omniauth-twitter'
  when "github"
    gem 'omniauth-github'
  end
end

# add omniauth initializer
initializer 'omniauth.rb', <<-CODE
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :developer unless Rails.env.production?
  # provider :twitter, ENV['TWITTER_KEY'], ENV['TWITTER_SECRET']
  # provider :facebook, ENV['FACEBOOK_KEY'], ENV['FACEBOOK_SECRET']
  # provider :github, ENV['GITHUB_KEY'], ENV['GITHUB_SECRET']
  # provider :google_oauth2, ENV['GOOGLE_CLIENT_ID'], ENV['GOOGLE_CLIENT_SECRET']
end
CODE

# add omniauth routes
route "get '/auth/:provider/callback', to: 'sessions#create'"
route "get '/auth/failure', to: redirect('/')"
route "get '/signout', to: 'sessions#destroy', as: 'signout'"

# add omniauth controller
file 'app/controllers/sessions_controller.rb', <<-CODE
class SessionsController < ApplicationController
  def create
    auth = request.env['omniauth.auth']
    user = User.find_by_provider_and_uid(auth['provider'], auth['uid']) || User.create_with_omniauth(auth)
    session[:user_id] = user.id
    redirect_to root_url, notice: 'Signed in!'
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_url, notice: 'Signed out!'
  end
end
CODE

# add user model
file 'app/models/user.rb', <<-CODE
class User < ApplicationRecord
  def self.create_with_omniauth(auth)
    create! do |user|
      user.provider = auth['provider']
      user.uid = auth['uid']
      user.name = auth['info']['name']
    end
  end
end
CODE

# add sessions views
file 'app/views/sessions/create.html.erb', <<-CODE
<h1>Successfully signed in!</h1>
CODE

file 'app/views/sessions/destroy.html.erb', <<-CODE
<h1>Successfully signed out!</h1>
CODE


# configure database
environment "config.active_record.schema_format = :sql", env: 'development'

# write database.yml
file 'config/database.yml', <<-CODE
default: &default
  adapter: postgresql
  encoding: unicode
  host: <%= ENV.fetch('POSTGRES_HOST', 'localhost') %>
  port: <%= ENV.fetch('POSTGRES_PORT', 5432) %>
  pool: <%= ENV.fetch('RAILS_MAX_THREADS', 5) %>
  username: postgres
  password: postgres

development:
  <<: *default
  database: #{@app_name}_development

test:
  <<: *default
  database: #{@app_name}_test

production:
  url: <%= ENV['DATABASE_URL'] %>
CODE
