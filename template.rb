# this is a rails template

def add_gems
  gem 'devise'
  gem 'omniauth'
  gem 'omniauth-rails_csrf_protection'

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

  # slim
  gem 'slim-rails'
  gem 'simple_form'

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
    gem 'hotwire-livereload', require: false
  end
end

def configure_omniauth
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
  route "get '/auth/:provider/callback', to: 'omniauth_sessions#create'"
  route "get '/auth/failure', to: redirect('/')"
  route "get '/signout', to: 'sessions#destroy', as: 'signout'"
end

def install_devise
  generate 'devise:install'

  #  write config.action_mailer.default_url_options = { host: 'localhost', port: 3000 } in development.rb
  ['development', 'test', 'production'].each do |env|
    insert_into_file "config/environments/#{env}.rb", before: /^end$/ do
      <<-CODE
      config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
      CODE
    end
  end

  insert_into_file 'config/initializers/devise.rb', after: "config.omniauth :github.*$" do
    <<-CODE
    config.omniauth :developer
    CODE
  end

  generate 'devise User'
end

def create_omniauth_session_controller
  # generate omniauth controller
  generate :controller, 'OmniauthSessions create destroy'

  # insert omniauth controller code
  insert_into_file 'app/controllers/omniauth_sessions_controller.rb', after: "def create\n" do
    <<-CODE
      auth = request.env['omniauth.auth']

      user = User.find_or_create_by_auth(auth)

      sign_in(user)
      redirect_to root_url, notice: 'Signed in!'
    CODE
  end

  insert_into_file 'app/controllers/omniauth_sessions_controller.rb', after: "def destroy\n" do
    <<-CODE
      sign_out
      redirect_to root_url, notice: 'Signed out!'
    CODE
  end
end

def add_omniauth_to_user_model
  # insert user model code
  insert_into_file 'app/models/user.rb', before: /^end/ do
    <<-CODE
  has_many :identities, dependent: :destroy

  def self.find_or_create_by_auth(auth)
    identity = Identity.find_by(provider: auth['provider'], uid: auth['uid'])
    identity&.user || create_with_omniauth(auth)
  end

  def self.create_with_omniauth(auth)
    create! do |user|
      identity = Identity.build(provider: auth['provider'], uid: auth['uid'])
      user.identities << identity
      user.email = auth['info']['email']
      user.password = Devise.friendly_token[0, 20]
    end
  end
    CODE
  end
end

def init_docker_compose
  file 'docker-compose.yml', <<-CODE
    version: '3.3'
    services:
      postgres:
        image: postgres:14
        container_name: postgres_#{@app_name}
        ports:
        - '127.0.0.1:5432:5432'
        environment:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_HOST_AUTH_METHOD: "trust"
        volumes:
          - ${PWD}/db:${PWD}/db
      redis:
        image: redis:7
        ports:
          - '127.0.0.1:6379:6379'
        container_name: redis_#{@app_name}
  CODE
end

def configure_database
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
end

def configure_rubocop
  # write rubocop.yml
  file '.rubocop.yml', <<-CODE
require:
  - rubocop-capybara
  - rubocop-factory_bot
  - rubocop-rspec
  - rubocop-rails
  - rubocop-rspec_rails

AllCops:
  TargetRubyVersion: 3.0
  NewCops: enable
  Exclude:
    - "db/schema.rb"
    - "bin/*"

Rails:
  Enabled: true

Style/Documentation:
  Enabled: false

Layout/LineLength:
  Max: 120

Metrics/BlockLength:
  Exclude:
    - 'spec/**/*'

  CODE

  run 'rubocop -A'
  run 'rubocop --auto-gen-config'
end

add_gems

run 'bundle install'

configure_omniauth

generate 'simple_form:install'
generate 'rspec:install'

install_devise

generate :model, 'Identity user:references provider:string uid:string'

generate :controller, 'home index'

insert_into_file 'app/views/home/index.html.slim' do
<<-CODE
container.block
  h1 class="text-3xl font-extrabold text-gray-900 block w-screen"
    |Home#index coucou

  p Find me in app/views/home/index.html.slim
  h2.block-title Sign in links
  ul.w-40.flex.flex-col.space-y-2
    = form_tag('/auth/developer', method: 'post', data: {turbo: false}) do
      button type='submit' class="rounded-md bg-indigo-600 px-2.5 py-1.5 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
        |Login with Developer

    li class="rounded-md bg-indigo-600 px-2.5 py-1.5 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
      = link_to 'Sign in with Email', '/users/sign_in'
CODE
end

route "root to: 'home#index'"

create_omniauth_session_controller

add_omniauth_to_user_model

init_docker_compose

configure_database

configure_rubocop
