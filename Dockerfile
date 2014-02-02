FROM howareyou/ruby:2.0.0-p247

ADD ./ /var/apps/server_responder

RUN \
  . /.profile ;\
  rm -fr /var/apps/server_responder/.git ;\
  cd /var/apps/server_responder ;\
  bundle install --local ;\
# END RUN

CMD . /.profile && cd /var/apps/server_responder && bundle exec rake && bundle exec rackup -p 8999

EXPOSE 8999