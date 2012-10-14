__Server Responder__  
An app that runs various commands when asked. It can be spun up on EC2 servers on demand pushes results to S3 and shuts itself back down. Currently to shut down, it writes a file of the last job time and exposes that time as a api endpoint. Then a cron running on the deffered-server frontend polls that endpoint and after not seeing any work done for awhile asks the server_responder app to shut down.

__To Run Locally__  
`bundle exec thin -R config.ru start`

__Data Recieved__  
  example push data: https://help.github.com/articles/post-receive-hooks

__TODO__  

  * a way to protect environment variables needed for S3 or a safe way to have one user drop to another which writes to S3  
  * user environments or other way to secure between runs (different servers per users?)   
  * a way to setup required environment like DB, memcache, redis, etc (follow travis CIs lead)  
  * a way to run one of these locally opposed to on EC2, perhaps vagrant setup?  