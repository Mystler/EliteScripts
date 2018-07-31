require 'rubygems'
require 'bundler/setup'
require 'json'
require 'matrix'
require 'kramdown'

$md = StringIO.new

$md.puts '# Aisling Duval Report'
$md.puts '{:.no_toc}'
$md.puts "*Generated: #{Time.now}*"
$md.puts
$md.puts '### Table of Contents'
$md.puts '{:.no_toc}'
$md.puts '* TOC'
$md.puts '{:toc}'
$md.puts

# Total data
factions = JSON.parse(File.read('factions.json'))
systems = JSON.parse(File.read('systems_populated.json'))

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

# Helper
def pretty_print(title, arr, desc = nil)
  $md.puts "### #{title}"
  if desc
    $md.puts "*#{desc}*"
    $md.puts
  end
  arr.each do |el|
    $md.puts "- #{el}"
  end
  $md.puts 'NONE' if arr.empty?
  $md.puts
  $md.puts '[To Top](#)'
  $md.puts
end

def link_to_system(system)
  return "#{system['name']} <sup>[E](https://eddb.io/system/#{system['id']}){:target=\"_blank\"} [M](https://www.edsm.net/en/system/id/#{system['edsm_id']}/name/#{system['name']}){:target=\"_blank\"} [I](https://inara.cz/search/?location=search&searchglobal=#{system['name']}){:target=\"_blank\"}</sup>"
end

def link_to_faction(faction)
  return "#{faction['name']} <sup>[E](https://eddb.io/faction/#{faction['id']}){:target=\"_blank\"} [I](https://inara.cz/search/?location=search&searchglobal=#{faction['name']}){:target=\"_blank\"}</sup>"
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
ctrl_bonus_impossible = []
ctrl_bonus_incomplete = []
ctrl_weak = []
ctrl_radius_profit = []
fac_fav_push = []
fac_fav_war = []
fac_fav_boom = []

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
      fac_fav_war.push "#{link_to_faction(fac['fac'])} --- #{fac['state']} in #{link_to_system(sys)}" if ['Civil War', 'War'].include? fac['state']
      fac_fav_boom.push link_to_faction(fac['fac']) if fac['state'] == 'Boom'
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
    ctrl_bonus_incomplete.push "#{link_to_system(ctrl_sys)} (#{fav_gov_count} of #{poss_fav_gov_count} in #{gov_count})"
    fac_fav_push += local_fac_fav_push
  elsif !poss_fav_gov
    ctrl_bonus_impossible.push "#{link_to_system(ctrl_sys)} (max #{poss_fav_gov_count}/#{gov_count})"
  end
  ctrl_weak.push "#{link_to_system(ctrl_sys)} (#{weak_gov_count}/#{gov_count})" if weak_gov

  upkeep = system_cc_upkeep(ctrl_sys['dist_to_cubeo'])
  radius_profit = (radius_income - upkeep - ad_system_cc_overhead).round(1)
  ctrl_radius_profit.push({control_system: ctrl_sys, profit: radius_profit, income: radius_income, upkeep: upkeep})
end

# Post processing
fac_fav_push.sort! { |x, y| y[:influence] <=> x[:influence] }
fac_fav_push_strings = fac_fav_push.map { |x| "#{link_to_faction(x[:faction])} in #{link_to_system(x[:system])} (#{x[:influence].round(1)}%) for Control System #{link_to_system(x[:control_system])}" }
fac_fav_push_strings.uniq!
fac_fav_war.uniq!
fac_fav_boom.uniq!
ctrl_radius_profit.sort! { |x, y| y[:profit] <=> x[:profit] }
ctrl_radius_profit_strings = ctrl_radius_profit.map { |x| "#{link_to_system(x[:control_system])} has a radius profit of #{x[:profit]} CC (In: #{x[:income]}, Upkeep: #{x[:upkeep]}, Overhead: #{ad_system_cc_overhead})" }

# Output
pretty_print('Control systems without active fortification bonus where possible', ctrl_bonus_incomplete)
pretty_print('Best factions to push to get fortification bonus', fac_fav_push_strings, 'Shows the best CCC factions in their system if there is no CCC in control and the sphere is flippable.')
pretty_print('Control systems that are UNFAVORABLE', ctrl_weak)
pretty_print('Control systems by radius profit', ctrl_radius_profit_strings, 'CC values calculated with experimental formulas.')
pretty_print('Warring favorable factions', fac_fav_war)
pretty_print('Booming favorable factions', fac_fav_boom)
pretty_print('Control systems with impossible fortification bonus', ctrl_bonus_impossible, 'These do not have CCCs in enough exploited systems (50% cannot be reached).')

# Write to file
File.open('AislingState.html', 'w') do |f|
  f.write Kramdown::Document.new($md.string, {template: 'AislingState.erb'}).to_html
end
