FROM alpine:3.6

ENV POST_SERVICE_HOST post
ENV POST_SERVICE_PORT 5000
ENV COMMENT_SERVICE_HOST comment
ENV COMMENT_SERVICE_PORT 9292

ARG APP_HOME=/app

RUN mkdir $APP_HOME
WORKDIR $APP_HOME
COPY Gemfile* $APP_HOME/
COPY . $APP_HOME

RUN apk --no-cache add -t tmp \
  ruby \
  build-base \
  ruby-dev \
  ruby-bundler \
  && apk --no-cache add ruby-json \
  && gem install bundler --no-ri --no-rdoc \
  && bundle install \
  && apk del tmp \
  && rm -rf /root/.bundle/cache

CMD ["puma"]
