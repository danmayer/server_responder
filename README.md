__Server Responder__
An app that runs various commands when asked. It can be spun up on EC2 servers on demand pushes results to S3 and shuts itself back down.

__To Run Locally__
`bundle exec thin -R config.ru start`

__Data Recieved__
  example push data: https://help.github.com/articles/post-receive-hooks

__TODO__
  * a way to protect environment variables needed for S3 or a safe way to have one user drop to another which writes to S3
  * A way for the server to shut itself down
  * user environments or other way to secure between runs (different servers per users?)
  * a way to setup required environment like DB, memcache, redis, etc (follow travis CIs lead)
  * a way to run one of these locally opposed to on EC2, perhaps vagrant setup?