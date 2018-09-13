require 'rubygems'
require 'bundler/setup'
require 'json'
require 'matrix'
require 'kramdown'

require_relative 'lib/EDSMClient'
require_relative 'AislingStateConfig'
require_relative 'AislingStateData'

advancedOut = StringIO.new
simpleOut = StringIO.new

# Write headers
[advancedOut, simpleOut].each do |out|
  out.puts '# Aisling Duval Report'
  out.puts '{:.no_toc .text-center}'
  out.puts '<p class="text-center"><img alt="Aisling Duval" src="aisling-duval.svg" width="200" height="200"></p>'
  out.puts "<p class=\"text-center\">Generated: <u><em class=\"timeago\" datetime=\"#{Time.now}\" data-toggle=\"tooltip\" title=\"#{Time.now}\"></em></u></p>"
  out.puts '<p class="text-center" markdown="1">'
  if out == simpleOut
    out.puts 'This is the simple report, based on priority targets and intended to help focus our BGS efforts.\\\\'
    out.puts 'For an unfiltered, advanced report [click here](advanced.html).'
  else
    out.puts 'This is the advanced report without filters and priorities, intended for full information and overview.\\\\'
    out.puts 'For the simple report for players [click here](index.html).'
  end
  out.puts '</p>'
  out.puts
  out.puts '<div class="card bg-darken">'
  out.puts '  <h3 class="card-header">Table of Contents</h3>'
  out.puts '  <div class="card-body" markdown="1">'
  out.puts '* TOC Entry'
  out.puts '{:toc}'
  out.puts '  </div>'
  out.puts '</div>'
  out.puts
end

# Total data
factions = JSON.parse(File.read('data/factions.json'))
systems = JSON.parse(File.read('data/systems_populated.json'))

# AD specific data subsets
ad_control = systems.select { |x| x['power'] == 'Aisling Duval' && x['power_state'] == 'Control' }
ad_exploited = systems.select { |x| x['power'] == 'Aisling Duval' && x['power_state'] == 'Exploited' }

# Inject faction refs and location vector into systems
faction_lookup = {}
factions.each do |fac|
  faction_lookup[fac['id']] = fac
end
systems.each do |sys|
  sys['location'] = Vector[sys['x'], sys['y'], sys['z']]
  sys['government_fac'] = faction_lookup[sys['government_id']]
  sys['minor_faction_presences'].each do |fac|
    fac['fac'] = faction_lookup[fac['minor_faction_id']]
  end
end

# Inject distance to Cubeo into AD systems
ad_cubeo = ad_control.find { |x| x['name'] == 'Cubeo' }
(ad_control + ad_exploited).each do |sys|
  sys['dist_to_cubeo'] = (sys['location'] - ad_cubeo['location']).r.round(1)
end

# Helpers
def is_strong_gov(obj)
  return ['cooperative', 'confederacy', 'communism'].include?(obj['government'].downcase) && obj['allegiance'] != 'Empire'
end

def is_weak_gov(obj)
  return ['feudal', 'prison colony', 'theocracy'].include?(obj['government'].downcase)
end

def is_conflicting(state)
  return ['civil war', 'war'].include?(state.downcase)
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
  'Control systems with impossible fortification bonus', 'fortify',
  'These do not have CCCs in enough exploited systems (50% cannot be reached).'
)
ctrl_bonus_incomplete = ControlSystemFlipStateDataSet.new('Control systems without active fortification bonus where possible', 'fortify')
ctrl_bonus_active = ControlSystemFlipStateDataSet.new('Control systems with active fortification bonus', 'fortify')
ctrl_weak = AislingDataSet.new('Control systems that are UNFAVORABLE', 'covert')
ctrl_weak.setTable(['Control System', 'Unfavorable Governments', 'Total Governments', 'From Cubeo'])
ctrl_radius_income = CCIncomeDataSet.new('Control systems by radius income', 'finance', 'CC values calculated with experimental formulas.')
ctrl_radius_profit = CCProfitDataSet.new('Control systems by radius profit', 'finance', 'CC values calculated with experimental formulas.')
fac_fav_push = FavPushFactionDataSet.new(
  'Best factions to push to get fortification bonus', 'fortify',
  'Shows the best CCC factions in their system if there is no CCC in control and the sphere is flippable.'
)
fac_fav_war = WarringCCCDataSet.new('Warring favorable factions', 'combat')
fac_fav_boom = BoomingCCCDataSet.new('Booming favorable factions', 'finance')

simple_spherestate = SimpleControlSystemFlipStateDataSet.new(
  'Control systems to focus on', 'fortify',
  'These are the spheres we want to flip next.'
)
simple_fac_push = SimpleFavPushFactionDataSet.new(
  'Best factions to push', 'fortify',
  'Shows the best CCC factions in their system for all our priority spheres.'
)
simple_data_drops = StationDropDataSet.new(
  'Recommended stations for data drops', 'finance',
  'Stations with factions we want to push in control.'
)
simple_fac_war = SimpleWarringCCCDataSet.new('Wars to support', 'combat')

# Process AD data
ad_system_cc_overhead = system_cc_overhead(ad_control.size + ad_exploited.size).round(1)
ad_control.each do |ctrl_sys|
  # Get exploited systems in profit area
  exploited = ad_exploited.select { |x| (x['location'] - ctrl_sys['location']).r <= 15.0 }

  # Add control system to exploited systems for easy iteration
  exploited.push ctrl_sys

  # Init counters
  gov_count = exploited.size
  fav_gov_count = 0
  weak_gov_count = 0
  poss_fav_gov_count = 0
  radius_income = 0

  priority = 9999 unless priority = AislingStateConfig.prioritySpheres[ctrl_sys['name']]

  # Process per system
  local_fac_fav_push = []
  exploited.each do |sys|
    sys_fav_facs = sys['minor_faction_presences'].select { |x| is_strong_gov(x['fac']) }
    sys_weak_facs = sys['minor_faction_presences'].select { |x| is_weak_gov(x['fac']) }

    fav_gov_count += 1 if is_strong_gov(sys)
    weak_gov_count += 1 if is_weak_gov(sys)
    poss_fav_gov_count += 1 if sys_fav_facs.any?
    radius_income += system_cc_income(sys['population'])

    best_fav_fac = nil
    sys_fav_facs.each do |fac|
      if !is_strong_gov(sys) && fac['minor_faction_id'] != sys['government_id']
        best_fav_fac = fac if !best_fav_fac || fac['influence'] > best_fav_fac['influence']
      end
      fac_fav_war.addItem({faction: fac, system: sys, control_system: ctrl_sys}) if is_conflicting(fac['state'])
      fac_fav_boom.addItem({faction: fac['fac'], system: sys, control_system: ctrl_sys}) if fac['state'] == 'Boom'
    end
    if best_fav_fac
      local_fac_fav_push.push({faction: best_fav_fac, system: sys, control_system: ctrl_sys})
      simple_fac_push.addItem({faction: best_fav_fac, system: sys, control_system: ctrl_sys, priority: priority}) if priority <= 3
    end

    if priority <= 3 and best_fav_fac
      if is_conflicting(best_fav_fac['state'])
        simple_fac_war.addItem({faction: best_fav_fac, system: sys, control_system: ctrl_sys, priority: priority})
      end
      edsm_stations = EDSMClient.getSystemStations(sys['name'])['stations']
      ccc_stations = edsm_stations.select { |x| x['controllingFaction']['name'] == best_fav_fac['fac']['name'] }
      edsm_factions = EDSMClient.getSystemFactions(sys['name'])['factions'] unless ccc_stations.empty?
      ccc_stations.each do |station|
        edsm_fac = edsm_factions.find { |x| x['name'] == station['controllingFaction']['name'] }
        edsm_fac_pending = []
        edsm_fac_pending = edsm_fac['pendingStates'].collect { |x| x['state'] } if edsm_fac['pendingStates']
        if !is_conflicting(edsm_fac['state']) and !edsm_fac_pending.find { |x| is_conflicting(x) }
          simple_data_drops.addItem({control_system: ctrl_sys, system: sys, station: station, faction: best_fav_fac,
                                     state: edsm_fac['state'], priority: priority})
        end
      end
    end
  end

  # Analyze
  fav_gov = fav_gov_count.to_f / gov_count.to_f
  poss_fav_gov = poss_fav_gov_count.to_f / gov_count.to_f
  weak_gov = weak_gov_count.to_f / gov_count.to_f
  item = {control_system: ctrl_sys, active_ccc: fav_gov_count, active_ccc_r: fav_gov,
          max_ccc: poss_fav_gov_count, max_ccc_r: poss_fav_gov, total_govs: gov_count, priority: priority}
  if fav_gov >= 0.5
    ctrl_bonus_active.addItem item
  elsif poss_fav_gov >= 0.5
    ctrl_bonus_incomplete.addItem item
    fac_fav_push.addItems local_fac_fav_push
  else
    ctrl_bonus_impossible.addItem item
  end
  simple_spherestate.addItem(item) if AislingStateConfig.prioritySpheres.has_key? ctrl_sys['name']
  ctrl_weak.addItem "#{link_to_system(ctrl_sys)} | #{weak_gov_count} | #{gov_count} | #{ctrl_sys['dist_to_cubeo']} LY" if weak_gov >= 0.5

  ctrl_radius_income.addItem({control_system: ctrl_sys, income: radius_income})
  upkeep = system_cc_upkeep(ctrl_sys['dist_to_cubeo'])
  radius_profit = (radius_income - upkeep - ad_system_cc_overhead).round(1)
  ctrl_radius_profit.addItem({control_system: ctrl_sys, profit: radius_profit, income: radius_income, upkeep: upkeep, overhead: ad_system_cc_overhead})
end

# Output
ctrl_bonus_incomplete.write(advancedOut)
fac_fav_push.write(advancedOut)
ctrl_weak.write(advancedOut)
fac_fav_war.write(advancedOut)
fac_fav_boom.write(advancedOut)
ctrl_bonus_active.write(advancedOut)
ctrl_bonus_impossible.write(advancedOut)
ctrl_radius_income.write(advancedOut)
ctrl_radius_profit.write(advancedOut)

simple_spherestate.write(simpleOut)
simple_fac_push.write(simpleOut) if simple_fac_push.hasItems()
simple_data_drops.write(simpleOut) if simple_data_drops.hasItems()
simple_fac_war.write(simpleOut) if simple_fac_war.hasItems()

# Write to files
File.open('html/advanced.html', 'w') do |f|
  f.write Kramdown::Document.new(advancedOut.string, {template: 'AislingState.erb'}).to_html
end
File.open('html/index.html', 'w') do |f|
  f.write Kramdown::Document.new(simpleOut.string, {template: 'AislingState.erb'}).to_html
end
