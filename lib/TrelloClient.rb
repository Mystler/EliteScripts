require_relative "APIClient"
require "yaml"

class TrelloClient < APIClient
  TrelloConfig = YAML.load(File.read("trello.yml"))

  def self.getAllConfigCards()
    return get("https://api.trello.com/1/boards/bORGBB8O/cards/?key=#{TrelloConfig["key"]}&token=#{TrelloConfig["token"]}&fields=name,desc,idList,idLabels")
  end

  def self.getAllADCards()
    return get("https://api.trello.com/1/boards/HBY3rRZR/cards/?key=#{TrelloConfig["key"]}&token=#{TrelloConfig["token"]}&fields=name,desc,idList,idLabels")
  end
end
