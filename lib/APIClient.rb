require 'net/http'
require 'net/https'
require 'json'

class APIClient
  def self.get(url, use_https = true)
    uri = URI.parse(url)
    request = Net::HTTP.new(uri.host, uri.port)
    if use_https
      request.use_ssl = true
      request.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    response = request.get(uri.request_uri)
    return nil if response.code != '200'
    return JSON.parse(response.body)
  end
end
