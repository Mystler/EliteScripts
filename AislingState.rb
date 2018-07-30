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

# Inject faction refs into systems
faction_lookup = {}
factions.each do |fac|
  faction_lookup[fac['id']] = fac
end
systems.each do |sys|
  sys['government_fac'] = faction_lookup[sys['government_id']]
  sys['minor_faction_presences'].each do |fac|
    fac['fac'] = faction_lookup[fac['minor_faction_id']]
  end
end

# Helper
def pretty_print(title, arr)
  $md.puts "### #{title}"
  arr.each do |el|
    $md.puts "- #{el}"
  end
  $md.puts 'NONE' if arr.empty?
  $md.puts
end

def link_to_system(system)
  return "#{system['name']} <sup>[E](https://eddb.io/system/#{system['id']}){:target=\"_blank\"} [M](https://www.edsm.net/en/system/id/#{system['edsm_id']}/name/#{system['name']}){:target=\"_blank\"} [I](https://inara.cz/search/?location=search&searchglobal=#{system['name']}){:target=\"_blank\"}</sup>"
end

def link_to_faction(faction)
  return "#{faction['name']} <sup>[E](https://eddb.io/faction/#{faction['id']}){:target=\"_blank\"} [I](https://inara.cz/search/?location=search&searchglobal=#{faction['name']}){:target=\"_blank\"}</sup>"
end

# Collecting data into these
ctrl_bonus_impossible = []
ctrl_bonus_incomplete = []
ctrl_weak = []
fac_fav_push = []
fac_fav_war = []
fac_fav_boom = []

# Process AD data
ad_control.each do |ctrl_sys|
  # Get exploited systems in profit area
  location = Vector[ctrl_sys['x'], ctrl_sys['y'], ctrl_sys['z']]
  exploited = ad_exploited.select { |x| (Vector[x['x'], x['y'], x['z']] - location).r <= 15.0 }

  # Add control system to exploited systems for easy iteration
  exploited.push ctrl_sys

  # Init counters
  gov_count = exploited.size
  fav_gov_count = 0
  weak_gov_count = 0
  poss_fav_gov_count = 0

  # Process per system
  local_fac_fav_push = []
  exploited.each do |sys|
    sys_fav_facs = sys['minor_faction_presences'].select { |x| strong_govs.include? x['fac']['government'] }
    sys_weak_facs = sys['minor_faction_presences'].select { |x| weak_govs.include? x['fac']['government'] }

    fav_gov_count += 1 if strong_govs.include? sys['government']
    weak_gov_count += 1 if weak_govs.include? sys['government']
    poss_fav_gov_count += 1 if sys_fav_facs.any?

    best_fav_fac = nil
    sys_fav_facs.each do |fac|
      if !strong_govs.include?(sys['government']) && fac['minor_faction_id'] != sys['government_id']
        best_fav_fac = fac if !best_fav_fac || fac['influence'] > best_fav_fac['influence']
      end
      fac_fav_war.push "#{link_to_faction(fac['fac'])} --- #{fac['state']} in #{link_to_system(sys)}" if ['Civil War', 'War'].include? fac['state']
      fac_fav_boom.push link_to_faction(fac['fac']) if fac['state'] == 'Boom'
    end
    if best_fav_fac
      local_fac_fav_push.push({'faction' => best_fav_fac['fac'], 'system' => sys, 'influence' => best_fav_fac['influence'], 'control_system' => ctrl_sys})
    end
  end

  # Analyse
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
end

# Post processing
fac_fav_push.sort! { |x, y| y['influence'] <=> x['influence'] }
fac_fav_push_strings = fac_fav_push.map { |x| "#{link_to_faction(x['faction'])} in #{link_to_system(x['system'])} (#{x['influence']}%) for Control System #{link_to_system(x['control_system'])}" }
fac_fav_push_strings.uniq!
fac_fav_war.uniq!
fac_fav_boom.uniq!

# Output
pretty_print('Control systems without active fortification bonus where possible', ctrl_bonus_incomplete)
pretty_print('Best factions to push to get fortification bonus', fac_fav_push_strings)
pretty_print('Control systems that are UNFAVORABLE', ctrl_weak)
pretty_print('Warring favorable factions', fac_fav_war)
pretty_print('Booming favorable factions', fac_fav_boom)
pretty_print('Control systems with impossible fortification bonus', ctrl_bonus_impossible)

# Write to file
File.open('AislingState.html', 'w') do |f|
  f.write Kramdown::Document.new($md.string, {template: 'AislingState.erb'}).to_html
end
