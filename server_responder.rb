get '/' do
  "I am alive:\n #{`churn`}"
end

post '/' do
  push = params
  "I got some JSON: #{push.inspect}"
end
