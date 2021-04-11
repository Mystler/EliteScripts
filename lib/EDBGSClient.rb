require_relative "APIClient"
require "time"

class EDBGSClient < APIClient
  BASE_URL = "https://elitebgs.app/api/ebgs/v5/"

  def self.getFaction(faction)
    return get("#{BASE_URL}factions?name=#{faction}")
  end

  def self.getLastTick()
    data = get("#{BASE_URL}ticks")
    if data
      return Time.parse(data.first["time"])
    end
    return nil
  end
end
