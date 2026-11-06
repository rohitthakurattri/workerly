# Workerly API and jobs image. One image, two commands:
#   API:   bin/rails server            (default)
#   Jobs:  bundle exec sidekiq -C config/sidekiq.yml
#   Migrations (one-off task before a deploy): bin/rails db:migrate
ARG RUBY_VERSION=3.4.11
FROM ruby:$RUBY_VERSION-slim AS base
WORKDIR /rails
# ImageMagick re-encodes photos (strips EXIF/GPS); jemalloc keeps Ruby's memory flat.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl imagemagick libjemalloc2 libpq5 libyaml-0-2 && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD=libjemalloc.so.2 \
    RAILS_LOG_TO_STDOUT=1

FROM base AS build
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives
COPY Gemfile Gemfile.lock .ruby-version ./
RUN gem install bundler -v "$(tail -1 Gemfile.lock | tr -d ' ')" --no-document && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile
COPY . .
RUN bundle exec bootsnap precompile app/ lib/

FROM base
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /usr/local/bin/bundle* /usr/local/bin/
COPY --from=build /usr/local/lib/ruby/gems /usr/local/lib/ruby/gems
COPY --from=build /rails /rails
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p log tmp storage && chown -R rails:rails log tmp storage
USER 1000:1000
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s CMD curl -fsS http://localhost:3000/up || exit 1
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
