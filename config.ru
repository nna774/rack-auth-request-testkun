require 'rack'
require 'rack/auth/request'
require 'net/https'

class Rack::Auth::Request
  class Initiate
    def initialize(app, &initiator)
      @app, @initiator = app, initiator
    end

    def call(env)
      res = @app.call(env)

      return @initiator.call(env) if res[0] == 401

      res
    end
  end

  class Callback
    def initialize(app, callback_path, &callbacker)
      @app, @callback_path, @callbacker = app, callback_path, callbacker
    end

    def call(env)
      return @callbacker.call(env) if env['REQUEST_URI'].split(??, 2) == @callback_path

      @app.call(env)
    end
  end
end

use Rack::Auth::Request::Callback, '/_auth/callback' do |env|
  https = Net::HTTP.new('auth.dark-kuins.net', 443)
  https.use_ssl = true
  req = Net::HTTP::Get.new("/callback?#{env['QUERY_STRING']}")

  response = https.request(req)
  [ response.code.to_i, response.header, [ response.body ] ]
end

use Rack::Auth::Request::Initiate do |env|
  https = Net::HTTP.new('auth.dark-kuins.net', 443)
  https.use_ssl = true
  req = Net::HTTP::Get.new('/initiate')
  req['x-ngx-omniauth-initiate-back-to'] = "https://rack-auth-request-testkun.dark-kuins.net#{env['REQUEST_URI']}"
  req['x-ngx-omniauth-initiate-callback'] = 'https://rack-auth-request-testkun.dark-kuins.net/_auth/callback'
  req['cookie'] = env['HTTP_COOKIE']

  response = https.request(req)
  [ response.code.to_i, response.header, [ response.body ] ]
end

use Rack::Auth::Request do |env|
  https = Net::HTTP.new('auth.dark-kuins.net', 443)
  https.use_ssl = true
  req = Net::HTTP::Get.new('/test')
  req['x-ngx-omniauth-original-uri'] = 'https://rack-auth-request-testkun.dark-kuins.net/'
  req['cookie'] = env['HTTP_COOKIE']

  response = https.request(req)
  [ response.code.to_i, response.header, [ response.body ] ]
end

run lambda { |_|
  [
    200,
    { 'CONTENT_TYPE' => 'text/plain' },
    ['Hao!']
  ]
}
