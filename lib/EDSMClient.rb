require_relative "APIClient"

class EDSMClient < APIClient
  BASE_URL = "https://www.edsm.net/api-system-v1/"

  def self.getSystemFactionsByName(systemName)
    return get("#{BASE_URL}factions?systemName=#{systemName}&showHistory=1")
  end

  def self.getSystemFactionsById(systemId)
    return get("#{BASE_URL}factions?systemId=#{systemId}&showHistory=1")
  end

  def self.getSystemStations(systemName)
    return get("#{BASE_URL}stations?systemName=#{systemName}")
  end
end
