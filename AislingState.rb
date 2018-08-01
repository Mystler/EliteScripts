require 'rubygems'
require 'bundler/setup'
require 'json'
require 'matrix'
require 'kramdown'

require_relative 'AislingStateData'

mdout = StringIO.new

mdout.puts '# Aisling Duval Report'
mdout.puts '{:.no_toc .text-center}'
mdout.puts '<p class="text-center"><img alt="Aisling Duval" src="aisling-duval.svg" width="200" height="200"></p>'
mdout.puts "<p class=\"text-center\">Generated: <u><em class=\"timeago\" datetime=\"#{Time.now}\" data-toggle=\"tooltip\" title=\"#{Time.now}\"></em></u></p>"
mdout.puts
mdout.puts '<div class="card bg-darken">'
mdout.puts '  <h3 class="card-header">Table of Contents</h3>'
mdout.puts '  <div class="card-body" markdown="1">'
mdout.puts '* TOC Entry'
mdout.puts '{:toc}'
mdout.puts '  </div>'
mdout.puts '</div>'
mdout.puts

# Total data
factions = JSON.parse(File.read('data/factions.json'))
systems = JSON.parse(File.read('data/systems_populated.json'))

# AD specific data subsets
strong_govs = ['Cooperative', 'Confederacy', 'Communism']
weak_govs = ['Feudal', 'Prison Colony', 'Theocracy']
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
ad_control.each do |sys|
  sys['dist_to_cubeo'] = (sys['location'] - ad_cubeo['location']).r
end

# Helpers
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
ctrl_bonus_impossible = AislingDataSet.new(
  'Control systems with impossible fortification bonus', 'fortify',
  'These do not have CCCs in enough exploited systems (50% cannot be reached).'
)
ctrl_bonus_impossible.setTable(['Control System', 'Possible CCC Governments', 'Total Governments'])
ctrl_bonus_incomplete = AislingDataSet.new('Control systems without active fortification bonus where possible', 'fortify')
ctrl_bonus_incomplete.setTable(['Control System', 'CCC Governments', 'Possible CCC Governments', 'Total Governments'])
ctrl_weak = AislingDataSet.new('Control systems that are UNFAVORABLE', 'covert')
ctrl_weak.setTable(['Control System', 'Unfavorable Governments', 'Total Governments'])
ctrl_radius_income = CCIncomeDataSet.new('Control systems by radius income', 'finance', 'CC values calculated with experimental formulas.')
ctrl_radius_income.setTable(['Control System', 'Income'])
ctrl_radius_profit = CCProfitDataSet.new('Control systems by radius profit', 'finance', 'CC values calculated with experimental formulas.')
ctrl_radius_profit.setTable(['Control System', 'Profit', 'Income', 'Upkeep', 'Overhead'])
fac_fav_push = FavPushFactionDataSet.new(
  'Best factions to push to get fortification bonus', 'fortify',
  'Shows the best CCC factions in their system if there is no CCC in control and the sphere is flippable.'
)
fac_fav_push.setTable(['Faction', 'System', 'Influence', 'Sphere'])
fac_fav_war = AislingDataSet.new('Warring favorable factions', 'combat')
fac_fav_war.setTable(['Faction', 'Type', 'System'])
fac_fav_boom = AislingDataSet.new('Booming favorable factions', 'finance')
fac_fav_boom.setTable(['Faction'])

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

  # Process per system
  local_fac_fav_push = []
  exploited.each do |sys|
    sys_fav_facs = sys['minor_faction_presences'].select { |x| strong_govs.include? x['fac']['government'] }
    sys_weak_facs = sys['minor_faction_presences'].select { |x| weak_govs.include? x['fac']['government'] }

    fav_gov_count += 1 if strong_govs.include? sys['government']
    weak_gov_count += 1 if weak_govs.include? sys['government']
    poss_fav_gov_count += 1 if sys_fav_facs.any?
    radius_income += system_cc_income(sys['population'])

    best_fav_fac = nil
    sys_fav_facs.each do |fac|
      if !strong_govs.include?(sys['government']) && fac['minor_faction_id'] != sys['government_id']
        best_fav_fac = fac if !best_fav_fac || fac['influence'] > best_fav_fac['influence']
      end
      fac_fav_war.addItem "#{link_to_faction(fac['fac'])} | #{fac['state']} | #{link_to_system(sys)}" if ['Civil War', 'War'].include? fac['state']
      fac_fav_boom.addItem link_to_faction(fac['fac']) if fac['state'] == 'Boom'
    end
    if best_fav_fac
      local_fac_fav_push.push({faction: best_fav_fac['fac'], system: sys, influence: best_fav_fac['influence'], control_system: ctrl_sys})
    end
  end

  # Analyze
  fav_gov = fav_gov_count.to_f / gov_count.to_f >= 0.5
  poss_fav_gov = poss_fav_gov_count.to_f / gov_count.to_f >= 0.5
  weak_gov = weak_gov_count.to_f / gov_count.to_f >= 0.5
  if !fav_gov && poss_fav_gov
    ctrl_bonus_incomplete.addItem "#{link_to_system(ctrl_sys)} | #{fav_gov_count} | #{poss_fav_gov_count} | #{gov_count}"
    fac_fav_push.addItems local_fac_fav_push
  elsif !poss_fav_gov
    ctrl_bonus_impossible.addItem "#{link_to_system(ctrl_sys)} | #{poss_fav_gov_count} | #{gov_count}"
  end
  ctrl_weak.addItem "#{link_to_system(ctrl_sys)} | #{weak_gov_count} | #{gov_count}" if weak_gov

  ctrl_radius_income.addItem({control_system: ctrl_sys, income: radius_income})
  upkeep = system_cc_upkeep(ctrl_sys['dist_to_cubeo'])
  radius_profit = (radius_income - upkeep - ad_system_cc_overhead).round(1)
  ctrl_radius_profit.addItem({control_system: ctrl_sys, profit: radius_profit, income: radius_income, upkeep: upkeep, overhead: ad_system_cc_overhead})
end

# Output
ctrl_bonus_incomplete.write(mdout)
fac_fav_push.write(mdout)
ctrl_weak.write(mdout)
fac_fav_war.write(mdout)
fac_fav_boom.write(mdout)
ctrl_bonus_impossible.write(mdout)
ctrl_radius_income.write(mdout)
ctrl_radius_profit.write(mdout)

# Write to file
File.open('html/index.html', 'w') do |f|
  f.write Kramdown::Document.new(mdout.string, {template: 'AislingState.erb'}).to_html
end
