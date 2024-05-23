# this is a rails template

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
