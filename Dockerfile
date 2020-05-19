# FROM ruby:2.6.5

# RUN apt-get update -yq \
# && apt-get install curl gnupg -yq \
# && curl -sL https://deb.nodesource.com/setup_10.x | bash \
# && apt-get install nodejs -yq \
# && apt-get clean -y \
# && apk add yarn \
# && yarn --version \
# && gem install bundler \
# && apt-get update -yq \
# && apt-get install postgresql postgresql-contrib -yq \
# && apt-get install graphviz -yq \
# && apt-get update -yq  \
# && apt-get install imagemagick -yq \
# && npm install -g foreman \
# && apt-get update -yq

# ADD . /app/

# WORKDIR /app/webapp

# RUN ./bin/setup

# EXPOSE 3000

# CMD nf start

FROM ruby:2.6.5-alpine

RUN apk add --update \
    && apk add nodejs \
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
    && rc-update add docker boot \
    && service docker start \
    && service docker status \
    && apk add git \
    && apk update && apk add --virtual build-dependencies build-base ruby-dev \
    && gem install bundler \
    && gem install pg \
    && gem pristine --all

ADD . /app/

WORKDIR /app/webapp

RUN ./bin/setup

EXPOSE 3000

CMD nf start