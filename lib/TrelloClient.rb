require_relative 'APIClient'
require 'yaml'

class TrelloClient < APIClient
  BASE_URL = 'https://api.trello.com/1/boards/bORGBB8O/'
  TrelloConfig = YAML.load(File.read("trello.yml"))

  def self.getAllCards()
    return get("#{BASE_URL}cards/?key=#{TrelloConfig['key']}&token=#{TrelloConfig['token']}&fields=name,desc,idList,idLabels")
  end
end
