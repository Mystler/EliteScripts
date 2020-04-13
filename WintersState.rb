require "rubygems"
require "bundler/setup"
require "json"
require "matrix"
require "kramdown"

require_relative "lib/EDSMClient"
require_relative "WintersStateConfig"
require_relative "WintersStateData"

advancedOut = StringIO.new

# Total data
systems = JSON.parse(File.read("data/systems_populated.json"))

# AD specific data subsets
fw_control = systems.select { |x| x["power"] == "Felicia Winters" && x["power_state"] == "Control" }
fw_exploited = systems.select { |x| x["power"] == "Felicia Winters" && x["power_state"] == "Exploited" }

# Inject location vector into systems
systems.each do |sys|
  sys["location"] = Vector[sys["x"], sys["y"], sys["z"]]
end

# Inject distance to HQ into power systems
fw_hq = fw_control.find { |x| x["name"] == "Rhea" }
(fw_control + fw_exploited).each do |sys|
  sys["dist_to_hq"] = (sys["location"] - fw_hq["location"]).r.round(1)
end

# Helpers
def is_strong_gov(obj)
  return false unless obj["government"]
  return ["corporate"].include?(obj["government"].downcase)
end

def is_weak_gov(obj)
  return false unless obj["government"]
  return ["feudal", "patronage", "communism", "cooperative"].include?(obj["government"].downcase)
end

# Collecting data into these
ctrl_bonus_impossible = ControlSystemFlipStateDataSet.new(
  "Control systems with impossible fortification bonus", "fortify",
  "These do not have Corps in enough exploited systems (50% cannot be reached)."
)
ctrl_bonus_incomplete = ControlSystemFlipStateDataSet.new("Control systems without active fortification bonus where possible", "fortify")
ctrl_bonus_active = ControlSystemFlipStateDataSet.new("Control systems with active fortification bonus", "fortify")
ctrl_weak = PowerDataSet.new("Control systems that are UNFAVORABLE", "covert")
ctrl_weak.setTable(["Control System", "Unfavorable Governments", "Total Governments", "From HQ"])
ctrl_radius_profit = CCProfitDataSet.new("Control systems by profit", "finance")
ctrl_upkeep = CCUpkeepDataSet.new("Control systems by upkeep costs", "finance", "CC values calculated with experimental formulas.")
ctrl_radius_income = CCIncomeDataSet.new("Control systems by radius income", "finance", "CC values calculated with experimental formulas.")
fac_fav_war = WarringCCCDataSet.new("Warring favorable factions", "combat")

# Process FW data
puts "Start processing..."
puts

fw_system_cc_overhead = system_cc_overhead(fw_control.size).round(1)
processed_income_systems = []
overlapped_systems = []
total_cc_income = 0
total_cc_upkeep = 0
total_cc_overheads = fw_system_cc_overhead * fw_control.size
fw_control.each do |ctrl_sys|
  puts "Processing control sphere #{ctrl_sys["name"]}..."

  # Get exploited systems in profit area
  exploited = fw_exploited.select { |x| (x["location"] - ctrl_sys["location"]).r <= 15.0 }

  # Add control system to exploited systems for easy iteration
  exploited.push ctrl_sys

  # Init counters
  gov_count = exploited.size
  fav_gov_count = 0
  weak_gov_count = 0
  poss_fav_gov_count = 0
  radius_income = 0
  total_ccc_inf = {now: 0, week: 0, month: 0}

  # Process per system
  local_fac_fav_push = []
  exploited.each do |sys|
    puts "Processing system #{sys["name"]} (#{sys["edsm_id"]})..."
    sys_fac_data = WintersStateConfig.cacheOnly? ? nil : EDSMClient.getSystemFactionsById(sys["edsm_id"])

    # EDSM Cache handling
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

    sys_facs = sys_fac_data["factions"].select { |x| x["influence"] > 0.0 }
    sys_fav_facs = sys_facs.select { |x| is_strong_gov(x) }
    sys_weak_facs = sys_facs.select { |x| is_weak_gov(x) }

    if !sys_fac_data["controllingFaction"]
      sys_fac_data["controllingFaction"] = sys_facs.max_by { |x| x["influence"] }
    end

    # Update last update timestamp for the entire system
    sys["updated_at"] = sys_fac_data["factions"].first["lastUpdate"]

    # Flip and CC state
    fav_gov_count += 1 if is_strong_gov(sys_fac_data["controllingFaction"])
    weak_gov_count += 1 if is_weak_gov(sys_fac_data["controllingFaction"])
    poss_fav_gov_count += 1 if sys_fav_facs.any?
    system_income = system_cc_income(sys["population"])
    radius_income += system_income
    sys["sys_cc_income"] = system_income

    if !processed_income_systems.include?(sys["name"])
      processed_income_systems.push sys["name"]
      total_cc_income += system_income
    elsif !overlapped_systems.include?(sys)
      overlapped_systems.push sys
    end

    # Investigate favourable faction
    best_fav_fac = nil
    sys_fav_facs.each do |fac|
      # Inject state strings
      fac["active_states_names"] = fac["activeStates"].collect { |x| x["state"] }
      fac["pending_states_names"] = fac["pendingStates"].collect { |x| x["state"] }
      fac["states_output"] = "#{fac["active_states_names"].empty? ? "None" : fac["active_states_names"].join(", ")}#{"<br>(Pending: " + fac["pending_states_names"].join(", ") + ")" if fac["pending_states_names"].any?}"

      if !is_strong_gov(sys_fac_data["controllingFaction"])
        best_fav_fac = fac if !best_fav_fac || fac["influence"] > best_fav_fac["influence"]
      end
      if is_conflicting(fac["active_states_names"] + fac["pending_states_names"])
        opponent = sys_facs.select { |x| x["id"] != fac["id"] && x["influence"] == fac["influence"] }.first
        control_war = if fac["id"] == sys_fac_data["controllingFaction"]["id"]
                        "Defending"
                      elsif !opponent
                        "???"
                      elsif opponent["id"] == sys_fac_data["controllingFaction"]["id"]
                        "Attacking"
                      else "No"                       end
        if !opponent || !is_strong_gov(opponent)
          fac_fav_war.addItem({faction: fac, system: sys, control_system: ctrl_sys, control_war: control_war})
        end
      end

      total_ccc_inf[:now] += fac["influence"]
      last_week = Time.now.to_i - 7 * 86400.0
      last_month = Time.now.to_i - 30 * 86400.0
      total_ccc_inf[:week] += fac["influenceHistory"]&.dig(fac["influenceHistory"]&.keys&.reject { |x| x.to_i > last_week }&.sort&.last) || fac["influence"]
      total_ccc_inf[:month] += fac["influenceHistory"]&.dig(fac["influenceHistory"]&.keys&.reject { |x| x.to_i > last_month }&.sort&.last) || fac["influence"]
    end
  end

  # Analyze
  fav_gov = fav_gov_count.to_f / gov_count.to_f
  poss_fav_gov = poss_fav_gov_count.to_f / gov_count.to_f
  weak_gov = weak_gov_count.to_f / gov_count.to_f
  needed_ccc = (gov_count * 0.5).ceil
  buffer_ccc = fav_gov_count - needed_ccc
  ctrl_sys["flip_data"] = {active_ccc: fav_gov_count, active_ccc_r: fav_gov, max_ccc: poss_fav_gov_count, max_ccc_r: poss_fav_gov, needed_ccc: needed_ccc, buffer_ccc: buffer_ccc, total_govs: gov_count}
  item = {control_system: ctrl_sys}
  if fav_gov >= 0.5
    ctrl_bonus_active.addItem item
  elsif poss_fav_gov >= 0.5
    ctrl_bonus_incomplete.addItem item
  else
    ctrl_bonus_impossible.addItem item
  end
  simple_spherestate.addItem(item) if WintersStateConfig.prioritySpheres.has_key? ctrl_sys["name"]
  ctrl_weak.addItem "#{link_to_system(ctrl_sys)} | #{weak_gov_count} | #{gov_count} | #{ctrl_sys["dist_to_hq"]} LY" if weak_gov >= 0.5

  ctrl_radius_income.addItem({control_system: ctrl_sys, income: radius_income})
  upkeep = system_cc_upkeep(ctrl_sys["dist_to_hq"])
  total_cc_upkeep += upkeep
  ctrl_upkeep.addItem({control_system: ctrl_sys, upkeep: upkeep})
  radius_profit = (radius_income - upkeep - fw_system_cc_overhead).round(1)
  ctrl_radius_profit.addItem({control_system: ctrl_sys, profit: radius_profit, income: radius_income, upkeep: upkeep, overhead: fw_system_cc_overhead})

  total_ccc_inf[:change_week] = total_ccc_inf[:now] - total_ccc_inf[:week]
  total_ccc_inf[:change_month] = total_ccc_inf[:now] - total_ccc_inf[:month]

  puts
end

# Post-pass
puts "Post-processing..."
puts

fw_control.each do |ctrl_sys|
  overlapped = overlapped_systems.select { |x| (x["location"] - ctrl_sys["location"]).r <= 15.0 }
  ctrl_sys["overlapped_systems_no"] = overlapped.size
  ctrl_sys["overlapped_systems_cc"] = overlapped.reduce(0) { |sum, x| sum + x["sys_cc_income"] }
end

# Output
ctrl_radius_profit.description = "CC values calculated with experimental formulas.<br><br>**Totals:** Income #{total_cc_income} CC, Upkeep #{total_cc_upkeep.round(0)} CC, Overheads #{total_cc_overheads.round(0)} CC<br>Expected Profit (No fortification) #{(total_cc_income - total_cc_upkeep - total_cc_overheads).round(0)} CC<br>Expected Profit (Full fortification) #{(total_cc_income - total_cc_overheads).round(0)} CC"

puts "Generating reports..."
puts

# Write headers
[advancedOut].each do |out|
  out.puts "# Felicia Winters Report"
  out.puts "{:.no_toc .text-center}"
  out.puts '<p class="text-center"><img alt="Felicia Winters" src="felicia-winters.svg" width="200" height="200"></p>'
  out.puts "<p class=\"text-center\">Generated: <u><em class=\"timeago\" datetime=\"#{Time.now}\" data-toggle=\"tooltip\" title=\"#{Time.now}\"></em></u></p>"
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
ctrl_weak.write(advancedOut)
ctrl_bonus_incomplete.write(advancedOut)
ctrl_bonus_active.write(advancedOut)
ctrl_bonus_impossible.write(advancedOut)
ctrl_radius_profit.write(advancedOut)
ctrl_upkeep.write(advancedOut)
ctrl_radius_income.write(advancedOut)

# Write to files
File.open("html/winters.html", "w") do |f|
  f.write Kramdown::Document.new(advancedOut.string, {template: "WintersState.erb"}).to_html
end

puts "Done!"
