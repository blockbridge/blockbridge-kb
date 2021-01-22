FROM jekyll/builder:3.8

WORKDIR /tmp
ADD Gemfile /tmp/
ADD Gemfile.lock /tmp/
RUN bundle install

FROM jekyll/jekyll:3.8

VOLUME /src
EXPOSE 4000

WORKDIR /src
ENTRYPOINT ["jekyll", "serve", "-H", "0.0.0.0"]
