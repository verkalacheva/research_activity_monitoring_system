source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.0.2'

gem 'rails', '~> 7.0.0'
gem 'pg', '~> 1.1'
gem 'puma', '~> 5.0'
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

# Business logic & pattern gems
gem 'dry-monads'
gem 'dry-validation'
gem 'dry-initializer'
gem 'interactor'

group :development, :test do
  gem 'debug', platforms: [:mri, :mingw, :x64_mingw]
end

group :development do
  gem 'anyway_config'
end

