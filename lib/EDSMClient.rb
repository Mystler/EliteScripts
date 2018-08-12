require_relative 'APIClient'

class EDSMClient < APIClient
  BASE_URL = 'https://www.edsm.net/api-system-v1/'

  def self.getSystemFactions(systemName)
    return get("#{BASE_URL}factions?systemName=#{systemName}")
  end

  def self.getSystemStations(systemName)
    return get("#{BASE_URL}stations?systemName=#{systemName}")
  end
end
