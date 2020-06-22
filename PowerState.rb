require "rubygems"
require "bundler/setup"
require "json"
require "matrix"
require "kramdown"
require "ostruct"
require "optparse"

options = {cache_only: false}
OptionParser.new do |opts|
  opts.banner = "Usage: PowerState.rb [options]"

  opts.on("-p", "--power=POWER", "Identifier for the power to generate a report for") do |power|
    PowerData = OpenStruct.new(YAML.load(File.read("powers.yml"))[power])

    if power == "aisling"
      require_relative "AislingStateConfig"
    end
  end

  opts.on("-c", "--cache-only", "Do not fetch new data from EDSM") do
    options[:cache_only] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if !defined?(PowerData)
  puts "ERROR: Missing power parameter."
  exit
end

require_relative "lib/EDBGSClient"
require_relative "lib/EDSMClient"
require_relative "PowerStateData"

# Total data
systems = JSON.parse(File.read("data/systems_populated.json"))

# Inject location vector into systems
systems.each do |sys|
  sys["location"] = Vector[sys["x"], sys["y"], sys["z"]]
end

# Power specific system subsets
systems_control = systems.select { |x| x["power"] == PowerData.name && (x["power_state"] == "Control" || x["power_state"] == "Home System") }
systems_exploited = systems.select { |x| x["power"] == PowerData.name && x["power_state"] == "Exploited" }
headquarters = systems.find { |x| x["name"] == PowerData.headquarters }

# Inject distance to HQ into power systems
(systems_control + systems_exploited).each do |sys|
  sys["dist_to_hq"] = (sys["location"] - headquarters["location"]).r.round(1)
end

# Power Helpers
def is_strong_gov(obj)
  return false unless obj["government"]
  return false if PowerData.strong_allegiance_blacklist && PowerData.strong_allegiance_blacklist.include?(obj["allegiance"].downcase)
  return PowerData.strong_govs.include?(obj["government"].downcase)
end

def is_weak_gov(obj)
  return false unless obj["government"]
  return PowerData.weak_govs.include?(obj["government"].downcase)
end

# Analyzation helpers
def is_conflicting(states)
  return (["civil war", "war"] & states.collect { |x| x.downcase }).any?
end

def system_cc_income(population)
  return 0 if population <= 0

  # Based on: https://www.reddit.com/r/EliteMahon/comments/3gua6m/calculation_for_radius_income/cu5yb7o/
  # Fitting factor I found is 3.1625
  return Math.log10(population.to_f / 3.1625).floor.clamp(2, 9) + 2
end

def system_cc_upkeep(dist)
  # Experimental fitting (via R) until I get some better formula
  return 20 unless dist > 0
  return (0.0000001977 * dist ** 3 + 0.0009336 * dist ** 2 + 0.006933 * dist + 0.333 + 20).round
end

def system_cc_overhead(no_of_systems)
  # Source see: https://www.reddit.com/r/EliteMahon/comments/3fq3h6/the_economics_of_powerplay/
  return [(11.5 * no_of_systems / 42) ** 3, 5.4 * 11.5 * no_of_systems].min.to_f / no_of_systems.to_f
end

# Collecting data into these
ctrl_bonus_impossible = ControlSystemFlipStateDataSet.new(
  "Control systems with impossible fortification bonus", "fortify",
  "These do not have favorable factions in enough exploited systems (50% cannot be reached)."
)
ctrl_bonus_incomplete = ControlSystemFlipStateDataSet.new("Control systems without active fortification bonus where possible", "fortify")
ctrl_bonus_active = ControlSystemFlipStateDataSet.new("Control systems with active fortification bonus", "fortify")
ctrl_weak = PowerDataSet.new("Control systems that are UNFAVORABLE", "covert")
ctrl_weak.setTable(["Control System", "Unfavorable Governments", "Total Governments", "From HQ"])
ctrl_radius_profit = CCProfitDataSet.new("Control systems by profit", "finance")
ctrl_upkeep = CCUpkeepDataSet.new("Control systems by upkeep costs", "finance", "CC values calculated with experimental formulas.")
ctrl_radius_income = CCIncomeDataSet.new("Control systems by radius income", "finance", "CC values calculated with experimental formulas.")
fac_fav_push = FavPushFactionDataSet.new(
  "Best factions to push for flipping", "fortify",
  "Shows the best factions in their system if there is no favorable one in control and the sphere is flippable."
)
fac_fav_war = WarringCCCDataSet.new("Warring favorable factions", "combat")
ctrl_trends = TopCCCInfMovements.new("Favourable factions influence movements", "eye", "Lists control spheres by changes in total percent points of influence in favorables.")
retreats = RetreatsDataSet.new("Noteworthy retreats", "combat")
fac_fav_defense = FavFacDefenseDataSet.new(
  "Best factions to push for defense", "fortify",
  "Shows favorable factions that are in control but do not have a high lead."
)

simple_spherestate = SimpleControlSystemFlipStateDataSet.new(
  "Control systems to focus on", "fortify",
  "These are the spheres we want to focus on."
)
simple_fac_push = SimpleFavPushFactionDataSet.new(
  "Best factions to push for flipping", "fortify",
  "Shows the best factions in their system for all our priority spheres."
)
simple_defense = SimpleFavFacDefenseDataSet.new(
  "Best factions to push for defense", "fortify",
  "Shows favorable factions that are in control but do not have a high lead."
)
#simple_data_drops = StationDropDataSet.new(
#  "Recommended stations for data drops", "finance",
#  "Stations with favorable factions in control."
#)
simple_fac_war = SimpleWarringCCCDataSet.new("Wars to support", "combat")

# Process data
puts "Start processing..."
puts

power_system_cc_overhead = system_cc_overhead(systems_control.size).round(1)
processed_income_systems = []
overlapped_systems = []
total_cc_income = 0
total_cc_upkeep = 0
total_cc_overheads = power_system_cc_overhead * systems_control.size
systems_control.each do |ctrl_sys|
  puts "Processing control sphere #{ctrl_sys["name"]}..."

  # Get exploited systems in profit area
  exploited = systems_exploited.select { |x| (x["location"] - ctrl_sys["location"]).r <= 15.0 }

  # Add control system to exploited systems for easy iteration
  exploited.push ctrl_sys

  # Init counters
  gov_count = 0
  fav_gov_count = 0
  weak_gov_count = 0
  poss_fav_gov_count = 0
  radius_income = 0
  total_ccc_inf = {now: 0, week: 0, month: 0}

  # Get or inject Trello priorities for AD
  priority = 9999
  ctrl_sys["fortPrio"] = 9999
  ctrl_sys["fortPrioText"] = "Unknown"
  if defined?(AislingStateConfig)
    priority = AislingStateConfig.prioritySpheres[ctrl_sys["name"]] || 9999
    ctrl_sys["fortPrio"] = AislingStateConfig.fortPriorities[ctrl_sys["name"]] || 9999
    ctrl_sys["fortPrioText"] = case ctrl_sys["fortPrio"]
                               when 1
                                 "Top"
                               when 2
                                 "Higher"
                               when 3
                                 "High"
                               else
                                 "None"
                               end
    ctrl_sys["fortPrioText"] = "Do Not Fort" if AislingStateConfig.blacklistFortify.include?(ctrl_sys["name"])
  end

  # Process per system
  local_fac_fav_push = []
  exploited.each do |sys|
    puts "Processing system #{sys["name"]} (#{sys["edsm_id"]})..."

    # EDSM Faction data and cache handling
    sys_fac_data = options[:cache_only] ? nil : EDSMClient.getSystemFactionsById(sys["edsm_id"])
    cache_file = "data/edsm_cache/#{sys["edsm_id"]}.json"
    if sys_fac_data
      File.open(cache_file, "w") do |file|
        file.write JSON.generate(sys_fac_data)
      end
    else
      begin
        sys_fac_data = JSON.parse(File.read(cache_file))
      rescue
        next
      end
    end

    next if sys_fac_data["factions"].empty?

    # CC contribution
    system_income = system_cc_income(sys["population"])
    radius_income += system_income
    sys["sys_cc_income"] = system_income

    if !processed_income_systems.include?(sys["name"])
      processed_income_systems.push sys["name"]
      total_cc_income += system_income
    elsif !overlapped_systems.include?(sys)
      overlapped_systems.push sys
    end

    # Skip control system for the rest because since January 2020 it does not seem to matter for BGS flip state
    next if sys == ctrl_sys

    # Faction var prep
    sys_facs = sys_fac_data["factions"].select { |x| x["influence"] > 0.0 }
    sys_fav_facs = sys_facs.select { |x| is_strong_gov(x) }
    sys_weak_facs = sys_facs.select { |x| is_weak_gov(x) }

    if !sys_fac_data["controllingFaction"]
      sys_fac_data["controllingFaction"] = sys_facs.max_by { |x| x["influence"] }
    end
    sys_controller = sys_fac_data["factions"].find { |x| x["id"] == sys_fac_data["controllingFaction"]["id"] }

    # Update last update timestamp for the entire system
    sys["updated_at"] = sys_fac_data["factions"].first["lastUpdate"]

    # Flip state counters
    gov_count += 1
    fav_gov_count += 1 if is_strong_gov(sys_controller)
    weak_gov_count += 1 if is_weak_gov(sys_controller)
    poss_fav_gov_count += 1 if sys_fav_facs.any?

    # Investigate favourable faction
    best_fav_fac = nil
    sys_fav_facs.each do |fac|
      # Inject state strings
      fac["active_states_names"] = fac["activeStates"].collect { |x| x["state"] }
      fac["pending_states_names"] = fac["pendingStates"].collect { |x| x["state"] }
      fac["states_output"] = "#{fac["active_states_names"].empty? ? "None" : fac["active_states_names"].join(", ")}#{"<br>(Pending: " + fac["pending_states_names"].join(", ") + ")" if fac["pending_states_names"].any?}"

      if !is_strong_gov(sys_controller)
        best_fav_fac = fac if !best_fav_fac || fac["influence"] > best_fav_fac["influence"]
      end
      if is_conflicting(fac["active_states_names"] + fac["pending_states_names"])
        opponent = sys_facs.select { |x| x["id"] != fac["id"] && x["influence"] == fac["influence"] }.first
        control_war = if fac["id"] == sys_controller["id"]
                        "Defending"
                      elsif !opponent
                        "???"
                      elsif opponent["id"] == sys_controller["id"]
                        "Attacking"
                      else "No"                       end
        if !opponent || !is_strong_gov(opponent)
          fac_fav_war.addItem({faction: fac, system: sys, control_system: ctrl_sys, control_war: control_war})

          if priority <= 3 && control_war != "No"
            simple_fac_war.addItem({faction: fac, system: sys, control_system: ctrl_sys, control_war: control_war, priority: priority})
          end
        end
      end

      total_ccc_inf[:now] += fac["influence"]
      last_week = Time.now.to_i - 7 * 86400.0
      last_month = Time.now.to_i - 30 * 86400.0
      total_ccc_inf[:week] += fac["influenceHistory"]&.dig(fac["influenceHistory"]&.keys&.reject { |x| x.to_i > last_week }&.sort&.last) || fac["influence"]
      total_ccc_inf[:month] += fac["influenceHistory"]&.dig(fac["influenceHistory"]&.keys&.reject { |x| x.to_i > last_month }&.sort&.last) || fac["influence"]
    end

    if best_fav_fac
      local_fac_fav_push.push({faction: best_fav_fac, system: sys, control_system: ctrl_sys})
      simple_fac_push.addItem({faction: best_fav_fac, system: sys, control_system: ctrl_sys, priority: priority}) if priority <= 3
    end

    if is_strong_gov(sys_controller) && !is_conflicting(sys_controller["active_states_names"] + sys_controller["pending_states_names"]) && sys_facs.size > 1
      influence_lead = sys_controller["influence"] - (sys_facs - [sys_controller]).sort_by { |x| [-x["influence"]] }.first["influence"]
      fac_fav_defense.addItem({faction: sys_controller, influence_lead: influence_lead, system: sys, control_system: ctrl_sys})
      simple_defense.addItem({faction: sys_controller, influence_lead: influence_lead, system: sys, control_system: ctrl_sys, priority: priority}) if priority <= 3
    end

    #    if priority <= 3 && is_strong_gov(sys_controller) && !is_conflicting(sys_controller["active_states_names"] + sys_controller["pending_states_names"])
    #      edsm_stations = EDSMClient.getSystemStations(sys["name"])["stations"]
    #      ccc_stations = edsm_stations.select { |x| x["controllingFaction"]["id"] == sys_controller["id"] }
    #      ccc_stations.each do |station|
    #        simple_data_drops.addItem({control_system: ctrl_sys, system: sys, station: station, faction: sys_controller, priority: priority})
    #      end
    #    end

    # Retreat investigation
    sys_facs.select { |x| (x["activeStates"] + x["pendingStates"]).any? { |y| y["state"] == "Retreat" } }.each do |retreat_fac|
      retreat_prio = 0
      if is_strong_gov(retreat_fac) && sys_fav_facs.size == 1
        retreat_info = "Last Fav in system"
        retreat_prio = 1
      elsif sys_facs.size >= 7
        retreat_info = "#{sys_facs.size}th faction#{" (Fav)" if is_strong_gov(retreat_fac)}"
        retreat_prio = 2
      elsif is_strong_gov(retreat_fac)
        retreat_info = "Fav"
        retreat_prio = 3
      end
      retreats.addItem({control_system: ctrl_sys, system: sys, faction: retreat_fac, retreat_info: retreat_info, retreat_prio: retreat_prio}) if retreat_prio > 0
    end
  end

  # Analyze
  fav_gov = gov_count == 0 ? 0.0 : fav_gov_count.to_f / gov_count.to_f
  poss_fav_gov = gov_count == 0 ? 0.0 : poss_fav_gov_count.to_f / gov_count.to_f
  weak_gov = gov_count == 0 ? 0.0 : weak_gov_count.to_f / gov_count.to_f
  needed_ccc = (gov_count * 0.5).to_i.next
  buffer_ccc = fav_gov_count - needed_ccc
  ctrl_sys["flip_data"] = {active_ccc: fav_gov_count, active_ccc_r: fav_gov, max_ccc: poss_fav_gov_count, max_ccc_r: poss_fav_gov, needed_ccc: needed_ccc, buffer_ccc: buffer_ccc, total_govs: gov_count}
  item = {control_system: ctrl_sys, priority: priority}
  if fav_gov > 0.5
    ctrl_bonus_active.addItem item
  elsif poss_fav_gov > 0.5
    ctrl_bonus_incomplete.addItem item
    fac_fav_push.addItems local_fac_fav_push
  else
    ctrl_bonus_impossible.addItem item
  end
  if defined?(AislingStateConfig)
    simple_spherestate.addItem(item) if AislingStateConfig.prioritySpheres.has_key? ctrl_sys["name"]
  end
  ctrl_weak.addItem "#{link_to_system(ctrl_sys)} | #{weak_gov_count} | #{gov_count} | #{ctrl_sys["dist_to_hq"]} LY" if weak_gov > 0.5

  ctrl_radius_income.addItem({control_system: ctrl_sys, income: radius_income})
  upkeep = system_cc_upkeep(ctrl_sys["dist_to_hq"])
  total_cc_upkeep += upkeep
  ctrl_upkeep.addItem({control_system: ctrl_sys, upkeep: upkeep})
  radius_profit = (radius_income - upkeep - power_system_cc_overhead).round(1)
  ctrl_radius_profit.addItem({control_system: ctrl_sys, profit: radius_profit, income: radius_income, upkeep: upkeep, overhead: power_system_cc_overhead})

  total_ccc_inf[:change_week] = total_ccc_inf[:now] - total_ccc_inf[:week]
  total_ccc_inf[:change_month] = total_ccc_inf[:now] - total_ccc_inf[:month]

  ctrl_trends.addItem({control_system: ctrl_sys, total_ccc_inf: total_ccc_inf})

  puts
end

# Post-pass
puts "Post-processing..."
puts

systems_control.each do |ctrl_sys|
  overlapped = overlapped_systems.select { |x| (x["location"] - ctrl_sys["location"]).r <= 15.0 }
  ctrl_sys["overlapped_systems_no"] = overlapped.size
  ctrl_sys["overlapped_systems_cc"] = overlapped.reduce(0) { |sum, x| sum + x["sys_cc_income"] }
end

LastBGSTick = EDBGSClient.getLastTick()

# Output
ctrl_radius_profit.description = "CC values calculated with experimental formulas.<br><br>**Totals:** Income #{total_cc_income} CC, Upkeep #{total_cc_upkeep.round(0)} CC, Overheads #{total_cc_overheads.round(0)} CC<br>Expected Profit (No fortification) #{(total_cc_income - total_cc_upkeep - total_cc_overheads).round(0)} CC<br>Expected Profit (Full fortification) #{(total_cc_income - total_cc_overheads).round(0)} CC"

puts "Generating reports..."
puts

advancedOut = StringIO.new
simpleOut = StringIO.new

# Write headers
[advancedOut, simpleOut].each do |out|
  out.puts "# #{PowerData.name} Report"
  out.puts "{:.no_toc .text-center}"
  out.puts "<p class=\"text-center\"><img alt=\"#{PowerData.name}\" src=\"#{PowerData.icon}\" width=\"200\" height=\"200\"></p>"
  out.puts "<p class=\"text-center\">Generated: <u><em class=\"timeago\" datetime=\"#{Time.now}\" data-toggle=\"tooltip\" title=\"#{Time.now}\"></em></u></p>"
  out.puts '<p class="text-center" markdown="1">'
  if out == simpleOut
    out.puts 'This is the simple report, based on priority targets and intended to help focus our BGS efforts.\\\\'
    out.puts "For an unfiltered, advanced report [click here](#{PowerData.output})."
  else
    out.puts "This is the advanced report with only limited filters and priorities, intended for full information and overview."
    out.puts "<br>For the simple report for players [click here](index.html)." if PowerData.simple_output
    out.puts '<br><br><input id="hide-no-prio" type="checkbox" checked><label for="hide-no-prio">Hide entries without fortification priority</label>' if defined?(AislingStateConfig)
  end
  out.puts "</p>"
  out.puts
  out.puts '<div class="card bg-darken">'
  out.puts '  <h3 class="card-header">Table of Contents</h3>'
  out.puts '  <div class="card-body" markdown="1">'
  out.puts "* TOC Entry"
  out.puts "{:toc}"
  out.puts "  </div>"
  out.puts "</div>"
  out.puts
end

fac_fav_war.write(advancedOut)
retreats.write(advancedOut)
ctrl_weak.write(advancedOut)
ctrl_bonus_incomplete.write(advancedOut)
fac_fav_push.write(advancedOut)
ctrl_bonus_active.write(advancedOut)
fac_fav_defense.write(advancedOut)
ctrl_bonus_impossible.write(advancedOut)
ctrl_radius_profit.write(advancedOut)
ctrl_upkeep.write(advancedOut)
ctrl_radius_income.write(advancedOut)
ctrl_trends.write(advancedOut)

if PowerData.simple_output
  simple_spherestate.write(simpleOut)
  simple_fac_war.write(simpleOut) if simple_fac_war.hasItems()
  #simple_data_drops.write(simpleOut) if simple_data_drops.hasItems()
  simple_fac_push.write(simpleOut) if simple_fac_push.hasItems()
  simple_defense.write(simpleOut) if simple_defense.hasItems()
end

# Write to files
File.open("html/#{PowerData.output}", "w") do |f|
  f.write Kramdown::Document.new(advancedOut.string, {template: "PowerState.erb"}).to_html
end

if PowerData.simple_output
  File.open("html/#{PowerData.simple_output}", "w") do |f|
    f.write Kramdown::Document.new(simpleOut.string, {template: "PowerState.erb"}).to_html
  end
end

puts "Done!"
