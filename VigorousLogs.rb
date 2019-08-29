require "clipboard"
require_relative "lib/Interactive"
require_relative "lib/EliteJournal"
require_relative "lib/Helpers"

puts "================"
puts "= VigorousLogs ="
puts "================"
puts
puts "Welcome, this will generate your personal mission and drops report for the Prismatic Imperium, Branch of Vigor."
puts "THE REPORT WILL REQUIRE MANUAL CHECKING TO REMOVE UNVIABLE ENTRIES!"
puts

# User Prompts
starttime = Interactive.UserInputPrompt("Please enter your data timespan. (ISO 8601 format recommended, e.g. 2019-05-20 or 2019-05-20T12:34:56+2)", "Start Time")
puts
endtime = Interactive.UserInputPrompt("Optional parameter, no value or 0 will process all data up to now.", "End Time")
puts
puts "Processing..."
puts
puts

# Helpers
FactionStation = Struct.new(:name, :station, :system)
FactionSystem = Struct.new(:name, :system)

# Tracking Initialization
inf_map = {}
cart_data = {}
bonds = {}
bounties = {}

# Processing Vars
at_faction = nil
at_station = nil
in_system = nil
system_address_book = {}

# Read and count data
EliteJournal.each(["Docked", "MissionCompleted", "MultiSellExplorationData", "SellExplorationData", "RedeemVoucher"], starttime, endtime) do |entry|
  if entry["event"] == "Docked"
    at_station = entry["StationName"]
    in_system = entry["StarSystem"]
    at_faction = entry["StationFaction"]["Name"]
    system_address_book[entry["SystemAddress"]] = entry["StarSystem"]
  elsif entry["event"] == "MissionCompleted"
    entry["FactionEffects"].each do |inf_effect|
      inf_effect["Influence"].each do |inf_part|
        plusses = inf_part["Influence"].count("+")
        if plusses > 0 && !inf_effect["Faction"].empty?
          fac = FactionSystem.new(inf_effect["Faction"], system_address_book.dig(inf_part["SystemAddress"]))
          inf_map[fac] = inf_map[fac].to_i + plusses
        end
      end
    end
  elsif ["MultiSellExplorationData", "SellExplorationData"].include? entry["event"]
    fac = FactionStation.new(at_faction, at_station, in_system)
    cart_data[fac] = cart_data[fac].to_i + entry["BaseValue"]
  elsif entry["event"] == "RedeemVoucher"
    if entry["Type"] == "CombatBond"
      fac = FactionSystem.new(entry["Faction"], in_system)
      bonds[fac] = bonds[fac].to_i + entry["Amount"]
    elsif entry["Type"] == "bounty"
      entry["Factions"].each do |part|
        fac = FactionSystem.new(part["Faction"], in_system)
        bounties[fac] = bounties[fac].to_i + part["Amount"]
      end
    end
  end
end

puts "Prismatic Report"
puts "----------------"
puts

out = StringIO.new
cart_data.sort_by { |k, v| -v }.each do |fac, cr|
  out.puts "+#{Helpers.FormatNumber(cr)} cr cart data for #{fac.name} at #{fac.station} in #{fac.system}"
end
bonds.sort_by { |k, v| -v }.each do |fac, cr|
  out.puts "+#{Helpers.FormatNumber(cr)} cr combat bonds for #{fac.name} in #{fac.system}"
end
bounties.sort_by { |k, v| -v }.each do |fac, cr|
  out.puts "+#{Helpers.FormatNumber(cr)} cr bounty vouchers for #{fac.name} in #{fac.system}"
end
inf_map.sort_by { |k, v| -v }.each do |fac, inf|
  out.puts "+#{inf} inf for #{fac.name} in #{fac.system}"
end
puts out.string
Clipboard.copy out.string

puts
puts "Report has been copied to your clipboard!"
puts "Press enter to quit..."
Interactive.GetInputOrArg()
