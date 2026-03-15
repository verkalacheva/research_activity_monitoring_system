FROM ruby:3.2.2-slim AS base

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends build-essential libpq-dev nodejs && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN gem update --system && \
    gem install bundler -v 2.2.22 && \
    bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3

COPY . .

# Precompile assets if needed (depending on your setup)
# RUN bundle exec rake assets:precompile RAILS_ENV=production SECRET_KEY_BASE=dummy

EXPOSE 3000

CMD ["bundle", "exec", "rails", "s", "-p", "3000", "-b", "0.0.0.0", "-e", "production"]
