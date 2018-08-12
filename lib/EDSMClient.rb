require_relative 'APIClient'

class ESDMClient < APIClient
  BASE_URL = 'https://www.edsm.net/api-system-v1/'

  def self.getSystemFactions(systemName)
    return get("#{BASE_URL}factions?systemName=#{systemName}")
  end
end
