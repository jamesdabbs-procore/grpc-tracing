FROM ruby:2.7

RUN mkdir /code
WORKDIR /code

ADD Gemfile /code
# ADD Gemfile.lock /code
RUN bundle install

ADD . /code

ENTRYPOINT ["rackup", "-p", "8003", "--host", "0.0.0.0"]
