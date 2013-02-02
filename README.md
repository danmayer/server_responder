Server Responder
===

An app that runs various commands when asked. It can be spun up on EC2 servers on demand pushes results to S3 and shuts itself back down. Currently to shut down, it writes a file of the last job time and exposes that time as a api endpoint. Then a cron running on the deffered-server frontend polls that endpoint and after not seeing any work done for awhile asks the server_responder app to shut down.

__To Run Locally__
`bundle exec thin -R config.ru start`

__Data Recieved__
  example push data: https://help.github.com/articles/post-receive-hooks

__TODO__

  * a way to protect environment variables needed for S3 or a safe way to have one user drop to another which writes to S3 (possibly server responder is dumb and hits deferred-server to handle S3 file writes / reads)
  * a way to setup required environment like DB, memcache, redis, etc (follow travis CIs lead)
  * a way to run one of these locally opposed to on EC2, perhaps vagrant setup?
  * Server responder should know how to first setup a EC2 server if loaded on a blank image
  * user environments or other way to secure between runs (different servers per users?)
  * remove the server-files / server-commands dependencies… These either need to be in a gem or those commands are always run through the other endpoint…Keeping server responder really simpler and dumb
  * config files that can sepcific additional features to run after the default of pushing the results to S3, something like push this whole folder as run artifacts
  * accept only https connections require api token before doing anything
  * Build a version people can run on heroku which just doesn't allow you to install bundles and gems that heroku doesn't allow, but can still be called via signed scripts
  * Fix broken logging on passenger bitnami 1.9.2
  * Fix permissions issues on creating files and directories and project all 'projects' created by daemon/daemon can't be read by process

__Completed__

  * Allow a .deferred-server file to specify commands to run opposed to only supporting churn (churn is fallback default)