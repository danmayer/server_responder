Server Responder
===

An app that runs various commands when asked. It can be spun up on EC2 servers on demand pushes results to S3 and shuts itself back down. Currently to shut down, it writes a file of the last job time and exposes that time as a api endpoint. Then a cron running on the deffered-server front end polls that endpoint and after not seeing any work done for awhile asks the server_responder app to shut down.

__To Run Locally__  
`bundle exec thin -R config.ru start` or `bundle exec rackup -p 3000`

__Data Received__  
  example push data:  
  https://help.github.com/articles/post-receive-hooks

__TODO__

  * a way to protect environment variables needed for S3 or a safe way to have one user drop to another which writes to S3 (possibly server responder is dumb and hits deferred-server to handle S3 file writes / reads)
  * a way to run one of these locally opposed to on EC2, perhaps vagrant setup?
  * remove the server-files / server-commands dependencies… These either need to be in a gem or those commands are always run through the other endpoint…Keeping server responder really simply and dumb
  * Build a version people can run on heroku which just doesn't allow you to install bundles and gems that heroku doesn't allow, but can still be called via signed scripts
  * return results and exit status
  
__NOTES__
  
  * All logging is going to the `/opt/bitnami/apache2/logs/error_log` I want to have something like sinatra log in app/logs but since moving to the newer AMI it just crashes if I try to redirect the logging.

