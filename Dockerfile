FROM ruby:2.6.5-alpine

RUN apk add --update \
    && apk add nodejs \
    && apk add curl \
    && apk add postgresql-dev \
    && apk add --update nodejs npm \
    && apk add yarn \
    && apk add postgresql-client \
    && apk add imagemagick6 \
    && apk add graphviz \
    && yarn --version \
    && npm install -g foreman \
    && apk add docker openrc \
    && apk add docker-compose \
    && apk add docker-cli \
    && apk add git \
    && apk update && apk add --virtual build-dependencies build-base ruby-dev \
    && gem install bundler \
    && gem install pg \
    && gem pristine --all

ADD . /app/

WORKDIR /app/webapp

EXPOSE 3000

# RUN ./bin/setup

CMD ./bin/setup && nf start
