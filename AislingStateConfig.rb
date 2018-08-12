require_relative 'lib/TrelloClient'

# Singleton class to organize external config data
class AislingStateConfig
  @@initialized = false
  @@prioritySpheres = {}
  @@blacklistIgnored = ['Cubeo'] # Ignore in general because HQ cannot be fortified
  @@blacklistForitfy = []
  @@blacklistManagedByOthers = []

  def self.fetchData
    return if @@initialized
    trelloCards = TrelloClient.getAllCards()
    trelloCards.each do |card|
      if card['idList'] == '5b703831013c514391f8da54' #Priority List
        @@prioritySpheres[card['name']] = 3 if card['idLabels'].include? '5b7038e7e4f9e80f776aff92'
        @@prioritySpheres[card['name']] = 2 if card['idLabels'].include? '5b7038e1c5df543f2eaa1bef'
        @@prioritySpheres[card['name']] = 1 if card['idLabels'].include? '5b703886b3c6cd12a0631a4d'
      elsif card['idList'] == '5b703831013c514391f8da55' #Blacklist List
        @@blacklistForitfy.push(card['name']) if card['idLabels'].include? '5b703a2f3c4d581785b81b77'
        @@blacklistManagedByOthers.push(card['name']) if card['idLabels'].include? '5b703a23181a64117af2fbd7'
      end
    end
    @@initialized = true
  end

  def self.blacklistIgnored
    return @@blacklistIgnored
  end

  def self.blacklistForitfy
    fetchData
    return @@blacklistForitfy
  end

  def self.blacklistManagedByOthers
    fetchData
    return @@blacklistManagedByOthers
  end

  def self.blacklistCombined
    fetchData
    return @@blacklistIgnored + @@blacklistForitfy + @@blacklistManagedByOthers
  end

  def self.blacklistText
    fetchData
    return "*Spheres ignored as DO NOT FORTIFY: #{@@blacklistForitfy.join(', ')}*<br>\
    *Spheres ignored as managed by another group of players: #{@@blacklistManagedByOthers.join(', ')}*"
  end

  def self.prioritySpheres
    fetchData
    return @@prioritySpheres
  end
end
