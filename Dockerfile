FROM localhost:5000/deals_base

RUN apt-get update
RUN apt-get install -y git

ADD ./ /var/apps/server_responder

RUN \
  . /.profile ;\
  rm -fr /var/apps/server_responder/.git ;\
  cd /var/apps/server_responder ;\
  bundle install;\
  . /.profile && cd /var/apps/server_responder && bundle exec rake;\
# END RUN

CMD . /.profile && cd /var/apps/server_responder && bundle exec rackup -p 8999

EXPOSE 8999