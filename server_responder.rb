get '/' do
  "I am alive"
end

post '/' do
  push = params
  "I got some JSON: #{push.inspect}"
end
