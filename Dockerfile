FROM localhost:5000/ruby_base

ADD ./ /var/apps/server_responder

RUN \
  rm -fr /var/apps/server_responder/.git ;\
  cd /var/apps/server_responder ;\
  bundle install;\
  cd /var/apps/server_responder && bundle exec rake;\
# END RUN

CMD . /.profile && cd /var/apps/server_responder && bundle exec rackup -p 8999

EXPOSE 8999