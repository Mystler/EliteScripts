require_relative "lib/TrelloClient"

# Singleton class to organize external config data
class WintersStateConfig
  @@initialized = false
  @@prioritySpheres = {}
  @@fortPriorities = {}
  @@blacklistIgnored = ["Rhea"] # Ignore in general because HQ cannot be fortified
  @@blacklistFortify = []
  @@blacklistManagedByOthers = []
  @@cacheOnly = false # Debug switch, keep to false in production

  def self.blacklistIgnored
    return @@blacklistIgnored
  end

  def self.blacklistFortify
    return @@blacklistFortify
  end

  def self.blacklistManagedByOthers
    return @@blacklistManagedByOthers
  end

  def self.blacklistCombined
    return @@blacklistIgnored + @@blacklistFortify + @@blacklistManagedByOthers
  end

  def self.blacklistText
    return "*Spheres ignored as DO NOT FORTIFY: #{@@blacklistFortify.join(", ")}*<br>\
    *Spheres ignored as managed by another group of players: #{@@blacklistManagedByOthers.join(", ")}*"
  end

  def self.prioritySpheres
    return @@prioritySpheres
  end

  def self.fortPriorities
    return @@fortPriorities
  end

  def self.cacheOnly?
    return @@cacheOnly
  end
end
