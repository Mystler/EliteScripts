require "net/http"
require "net/https"
require "json"

class APIClient
  def self.get(url, use_https = true, min_wait = 10, recurse_cap = 5, is_recurse = 1)
    uri = URI.parse(url)
    request = Net::HTTP.new(uri.host, uri.port)
    if use_https
      request.use_ssl = true
      request.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    response = request.get(uri.request_uri)
    # Throttling
    if response.get_fields("X-Rate-Limit-Remaining") && response.get_fields("X-Rate-Limit-Limit") && response.get_fields("X-Rate-Limit-Reset") && response.get_fields("X-Rate-Limit-Remaining").first.to_i < 5
      wait_time = (response.get_fields("X-Rate-Limit-Reset").first.to_f / response.get_fields("X-Rate-Limit-Limit").first.to_f).ceil
      puts "Nearing request cap, waiting for #{wait_time} seconds..."
      sleep wait_time
    end
    if response.code == "429" && response.get_fields("Retry-After")
      wait_time = response.get_fields("Retry-After").first.to_i.clamp(min_wait, 60)
      return nil if is_recurse > recurse_cap
      puts "Too many requests, waiting for #{wait_time} seconds..."
      sleep wait_time
      return get(url, use_https, min_wait, recurse_cap, is_recurse + 1)
    end
    return nil if response.code != "200"
    return JSON.parse(response.body)
  end

  def self.post_json(url, data, use_https = true)
    uri = URI.parse(url)
    request = Net::HTTP.new(uri.host, uri.port)
    if use_https
      request.use_ssl = true
      request.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    response = request.post(uri.request_uri, JSON.generate(data), {"Content-Type" => "application/json"})
    puts response.inspect
    return nil if response.code != "200"
    return JSON.parse(response.body)
  end
end
