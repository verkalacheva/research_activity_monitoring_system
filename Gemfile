source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.2.2'

gem 'rails', '~> 7.0.0'
gem 'pg', '~> 1.1'
gem 'puma', '~> 5.0'
gem 'rack-cors'
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

# Business logic & pattern gems
gem 'dry-monads'
gem 'dry-validation'
gem 'dry-initializer'
gem 'interactor'

gem 'grpc'
gem 'google-protobuf'
gem 'grpc-tools'

group :development, :test do
  gem 'debug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'listen', '~> 3.3'
end

group :development do
  gem 'anyway_config'
end

