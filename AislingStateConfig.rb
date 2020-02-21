require_relative "lib/TrelloClient"

# Singleton class to organize external config data
class AislingStateConfig
  @@initialized = false
  @@prioritySpheres = {}
  @@fortPriorities = {}
  @@blacklistIgnored = ["Cubeo"] # Ignore in general because HQ cannot be fortified
  @@blacklistFortify = []
  @@blacklistManagedByOthers = []
  @@cacheOnly = false # Debug switch, keep to false in production

  def self.fetchData
    return if @@initialized
    trelloCards = TrelloClient.getAllConfigCards()
    trelloCards.each do |card|
      if card["idList"] == "5b703831013c514391f8da54" #Priority List
        @@prioritySpheres[card["name"]] = 3 if card["idLabels"].include? "5b7038e7e4f9e80f776aff92"
        @@prioritySpheres[card["name"]] = 2 if card["idLabels"].include? "5b7038e1c5df543f2eaa1bef"
        @@prioritySpheres[card["name"]] = 1 if card["idLabels"].include? "5b703886b3c6cd12a0631a4d"
      elsif card["idList"] == "5b703831013c514391f8da55" #Blacklist List
        @@blacklistFortify.push(card["name"]) if card["idLabels"].include? "5b703a2f3c4d581785b81b77"
        @@blacklistManagedByOthers.push(card["name"]) if card["idLabels"].include? "5b703a23181a64117af2fbd7"
      end
    end

    reached_do_not_fort = false
    trelloCards = TrelloClient.getAllADCards()
    trelloCards.each do |card|
      if card["idList"] == "56426feacf6120c172861893" #Fort List
        @@fortPriorities[card["name"].partition(/\s+-\s+/)[0]] = 3 if card["idLabels"].include? "56426feacf6120c17286189d" # High
        @@fortPriorities[card["name"].partition(/\s+-\s+/)[0]] = 2 if card["idLabels"].include? "56cb1c79152c3f92fd1fda4a" # Highest
        @@fortPriorities[card["name"].partition(/\s+-\s+/)[0]] = 1 if card["idLabels"].include? "56426feacf6120c1728618a5" # For the Princess
      elsif card["idList"] == "56dad9e692b8c972022eec9b" && card["name"] == "!!! DO NOT FORTIFY EVER !!!"
        reached_do_not_fort = true
      elsif card["idList"] == "56dad9e692b8c972022eec9b" && reached_do_not_fort && card["name"].include?("!!!")
        reached_do_not_fort = false
      elsif card["idList"] == "56dad9e692b8c972022eec9b" && reached_do_not_fort
        @@blacklistFortify.push(card["name"])
      end
    end
    @@blacklistFortify.uniq!
    @@initialized = true
  end

  def self.blacklistIgnored
    fetchData
    return @@blacklistIgnored
  end

  def self.blacklistFortify
    fetchData
    return @@blacklistFortify
  end

  def self.blacklistManagedByOthers
    fetchData
    return @@blacklistManagedByOthers
  end

  def self.blacklistCombined
    fetchData
    return @@blacklistIgnored + @@blacklistFortify + @@blacklistManagedByOthers
  end

  def self.blacklistText
    fetchData
    return "*Spheres ignored as DO NOT FORTIFY: #{@@blacklistFortify.join(", ")}*<br>\
    *Spheres ignored as managed by another group of players: #{@@blacklistManagedByOthers.join(", ")}*"
  end

  def self.prioritySpheres
    fetchData
    return @@prioritySpheres
  end

  def self.fortPriorities
    fetchData
    return @@fortPriorities
  end

  def self.cacheOnly?
    return @@cacheOnly
  end
end
