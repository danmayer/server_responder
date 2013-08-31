Server Responder
===

A tiny app that runs various commands when asked. Mostly it processes commands for other projects, it also can be used to run arbitrary code on a box. It tries to be very simple and lightweight so it can be configured on a 'throw away' cloud boxes and not require sensitive information or settings.

There are two primary uses cases:

1) In conjunction with a deferred server management app. It can be spun up on EC2 servers on demand pushes results to S3 and shuts itself back down. Currently to shut down, it writes a file of the last job time and exposes that time as a api endpoint. Then a cron running on deferred-server companion app polls that endpoint. After not seeing any work done for awhile shuts down the server running server responder.

2) Stand alone, for simple execution direct execution on a heroku box. This is mostly intended for embedded code example script runners.

__To Run Locally__  
`bundle exec thin -R config.ru start` or  
`bundle exec rackup -p 3000` or  
`foreman start`

__Example Github Data Received__  
  
  * [example push data](https://help.github.com/articles/post-receive-hooks)
  * to trigger an exception curl --data "api_token=XXX" "https://ec2-54-224-26-215.compute-1.amazonaws.com" --insecure

__TODO__

  * a way to protect environment variables needed for S3 or a safe way to have one user drop to another which writes to S3 (possibly server responder is dumb and hits deferred-server to handle S3 file writes / reads)
  * a way to run one of these locally opposed to on EC2, perhaps vagrant setup?
  * remove the server-files / server-commands dependencies… These either need to be in a gem or those commands are always run through the other endpoint…Keeping server responder really simply and dumb
  * Build a version people can run on heroku which just doesn't allow you to install bundles and gems that heroku doesn't allow, but can still be called via signed scripts
    * This is basically done with the example page now
    * how to handle signing, sign in deferred server? currently it calls directly
    * if the JS is in deferred server be configured to hit directly? or pass through deferred server, and write to tmp opposed to S3
    * on the public heroku server_responder no keys / more secure auth between systems No amazon creds
  * return results and exit status
  * improve debug / deployment cycle, local testing
  * project need to be able to setup their environment and share keys etc...?
  * need a utility to just pass a S3 fragment and have it cat the results for me

__NOTES__
  
  * All logging for EC2 boxes is going to the `/opt/bitnami/apache2/logs/error_log` I want to have something like Sinatra log in app/logs but since moving to the newer AMI it just crashes if I try to redirect the logging.

