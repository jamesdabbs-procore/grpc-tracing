FROM ruby:2.7

RUN mkdir /code
WORKDIR /code

ADD Gemfile /code
ADD Gemfile.lock /code
RUN bundle install --jobs 4 --retry 3

ADD . /code

ENTRYPOINT /code/server.rb
