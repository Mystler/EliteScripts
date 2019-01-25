require_relative "AislingStateConfig"

# General helper Functions
def str_to_id(str)
  gen_id = str.gsub(/^[^a-zA-Z]+/, "")
  gen_id.tr!("^a-zA-Z0-9 -", "")
  gen_id.tr!(" ", "-")
  gen_id.downcase!
  gen_id
end

def link_to_system(system)
  return "#{system["name"]} <sup>[E](https://eddb.io/system/#{system["id"]}){:target=\"_blank\"} [M](https://www.edsm.net/en/system/id/#{system["edsm_id"]}/name/#{system["name"]}){:target=\"_blank\"} [I](https://inara.cz/search/?location=search&searchglobal=#{system["name"]}){:target=\"_blank\"}</sup>"
end

def link_to_faction(faction)
  return "#{faction["name"]} <sup>[E](https://eddb.io/faction/#{faction["id"]}){:target=\"_blank\"} [I](https://inara.cz/search/?location=search&searchglobal=#{faction["name"]}){:target=\"_blank\"}</sup>"
end

def updated_at(el)
  time = Time.at(el["updated_at"])
  daysold = (Time.now - time) / 86400.0
  colorclass = "age-green"
  if daysold > 4
    colorclass = "age-red"
  elsif daysold > 1
    colorclass = "age-yellow"
  end
  return "<u><em class=\"timeago #{colorclass}\" datetime=\"#{time}\" data-toggle=\"tooltip\" title=\"#{time}\"></em></u>"
end

# Base class for reports.
# Only collecting strings as items and printing them in kramdown format.
# Override the private methods when working with objects. Preprocessing order is filter, uniq, sort.
class AislingDataSet
  def initialize(title, icon = nil, description = nil)
    @title = title
    @icon = icon
    @description = description
    @items = []
    @table = nil
  end

  def hasItems
    return !@items.empty?
  end

  def addItem(item)
    @items.push item
  end

  def addItems(items)
    @items += items
  end

  def setTable(columns)
    @table = columns
  end

  def write(out)
    out.puts '<div class="card bg-darken" markdown="1">'
    svg = @icon ? "<img class=\"ad-icon\" alt=\"#{@icon}\" src=\"#{@icon}.svg\"> " : ""
    out.puts "### #{svg}#{@title} {##{str_to_id(@title)}}"
    out.puts "{:.card-header}"
    out.puts '<div class="card-body" markdown="1">'
    if @description
      out.puts @description
      out.puts
    end
    filterDesc = filterText()
    if filterDesc
      out.puts filterDesc
      out.puts
    end

    lines = compileLines()
    @table ||= tableHeader() # Get table header from override if not set manually
    if @table && !lines.empty?
      out.puts '<div class="table-responsive" markdown="1">'
      out.puts "| " + @table.join(" | ")
      out.puts "| -" * @table.size
    end
    lines.each do |line|
      out.puts "#{@table ? "|" : "-"} #{line}"
    end
    if @table && !lines.empty?
      out.puts "{:.table .table-striped .table-borderless}"
      out.puts "</div>"
    end
    out.puts "NONE" if lines.empty?
    out.puts
    out.puts '<div class="text-right"><a href="#">Back to Top</a></div>'
    out.puts
    out.puts "</div></div>"
  end

  private

  def compileLines
    filter()
    uniq()
    sort()
    lines = []
    @items.each do |item|
      lines.push(itemToString(item))
    end
    return lines
  end

  ##################
  # Override these #
  ##################
  def itemToString(item)
    return item
  end

  def tableHeader
    return nil
  end

  def filter
    # NOOP
  end

  def filterText
    return nil
  end

  def uniq
    @items.uniq!
  end

  def sort
    @items.sort!
  end
end

# Expected Item properties: control_system, active_ccc, active_ccc_r, max_ccc, max_ccc_r, total_govs
class ControlSystemFlipStateDataSet < AislingDataSet
  def itemToString(item)
    active_percent = (100.0 * item[:active_ccc_r]).round(1)
    max_percent = (100.0 * item[:max_ccc_r]).round(1)
    return "#{link_to_system(item[:control_system])} | #{item[:active_ccc]} (#{active_percent}%) | #{item[:max_ccc]} (#{max_percent}%) \
    | #{item[:total_govs]} | #{item[:control_system]["dist_to_cubeo"]} LY"
  end

  def tableHeader
    return ["Control System", "CCC Governments", "Possible CCC Governments", "Total Governments", "From Cubeo"]
  end

  def filter
    @items.reject! { |x| AislingStateConfig.blacklistCombined.include?(x[:control_system]["name"]) }
  end

  def filterText
    return AislingStateConfig.blacklistText
  end

  def sort
    @items.sort_by! { |x| [-x[:active_ccc_r]] }
  end
end

class SimpleControlSystemFlipStateDataSet < AislingDataSet
  def itemToString(item)
    active_percent = (100.0 * item[:active_ccc_r]).round(1)
    max_percent = (100.0 * item[:max_ccc_r]).round(1)
    priority = (item[:priority] == 1 ? "Top" : (item[:priority] == 2 ? "High" : "Low"))
    return "#{link_to_system(item[:control_system])} | #{priority} | #{item[:active_ccc]} (#{active_percent}%) | #{item[:max_ccc]} (#{max_percent}%) \
    | #{item[:total_govs]} | #{item[:control_system]["dist_to_cubeo"]} LY"
  end

  def tableHeader
    return ["Control System", "Priority", "CCC Governments", "Possible CCC Governments", "Total Governments", "From Cubeo"]
  end

  def sort
    @items.sort_by! { |x| [x[:priority], -x[:active_ccc_r]] }
  end
end

# Expected Item properties: faction (in system object), system, control_system
class FavPushFactionDataSet < AislingDataSet
  def itemToString(item)
    return "#{link_to_faction(item[:faction]["fac"])} | #{item[:faction]["active_states_names"].join(", ")} | #{link_to_system(item[:system])} | #{item[:faction]["influence"].round(1)}% \
    | #{link_to_system(item[:control_system])} | #{item[:system]["dist_to_cubeo"]} LY | #{updated_at(item[:system])}"
  end

  def tableHeader
    return ["Faction", "States", "System", "Influence", "Sphere", "From Cubeo", "Updated"]
  end

  def filter
    @items.reject! { |x| AislingStateConfig.blacklistCombined.include?(x[:control_system]["name"]) }
  end

  def filterText
    return AislingStateConfig.blacklistText
  end

  def sort
    @items.sort_by! { |x| [x[:control_system]["dist_to_cubeo"], -x[:faction]["influence"]] }
  end
end

class SimpleFavPushFactionDataSet < AislingDataSet
  def itemToString(item)
    return "#{link_to_faction(item[:faction]["fac"])} | #{item[:faction]["active_states_names"].join(", ")} | #{link_to_system(item[:system])} | #{item[:faction]["influence"].round(1)}% \
    | #{link_to_system(item[:control_system])} | #{item[:system]["dist_to_cubeo"]} LY | #{updated_at(item[:system])}"
  end

  def tableHeader
    return ["Faction", "States", "System", "Influence", "Sphere", "From Cubeo", "Updated"]
  end

  def sort
    @items.sort_by! { |x| [x[:priority], x[:control_system]["dist_to_cubeo"], -x[:faction]["influence"]] }
  end
end

# Expected Item properties: faction (in system object), system, control_system
class WarringCCCDataSet < AislingDataSet
  def itemToString(item)
    return "#{link_to_faction(item[:faction]["fac"])} | #{item[:faction]["active_states_names"].join(", ")} | #{link_to_system(item[:system])} | \
    #{link_to_system(item[:control_system])} | #{item[:system]["dist_to_cubeo"]} LY | #{updated_at(item[:system])}"
  end

  def tableHeader
    return ["Faction", "States", "System", "Sphere", "From Cubeo", "Updated"]
  end

  def filter
    @items.reject! { |x| AislingStateConfig.blacklistCombined.include?(x[:control_system]["name"]) }
  end

  def filterText
    return AislingStateConfig.blacklistText
  end

  def sort
    @items.sort_by! { |x| [x[:control_system]["dist_to_cubeo"], x[:system]["dist_to_cubeo"]] }
  end
end

class SimpleWarringCCCDataSet < AislingDataSet
  def itemToString(item)
    return "#{link_to_faction(item[:faction]["fac"])} | #{item[:faction]["active_states_names"].join(", ")} | #{link_to_system(item[:system])} | \
    #{link_to_system(item[:control_system])} | #{item[:system]["dist_to_cubeo"]} LY | #{updated_at(item[:system])}"
  end

  def tableHeader
    return ["Faction", "States", "System", "Sphere", "From Cubeo", "Updated"]
  end

  def sort
    @items.sort_by! { |x| [x[:priority], x[:control_system]["dist_to_cubeo"], x[:system]["dist_to_cubeo"]] }
  end
end

# Add all entries found, this will automatically be reduced to display per faction data
# Expected Item properties: faction, system, control_system
class BoomingCCCDataSet < AislingDataSet
  def itemToString(item)
    out = "#{link_to_faction(item[:faction])} | "
    item[:systems].each_with_index do |sys, i|
      out += "<br>" if i > 0
      out += link_to_system(sys)
    end
    out += " | "
    item[:spheres].each_with_index do |sys, i|
      out += "<br>" if i > 0
      out += link_to_system(sys)
    end
    out += " | #{item[:avg_from_cubeo]} LY | #{updated_at(item[:faction])}"
    return out
  end

  def tableHeader
    return ["Faction", "Systems", "Spheres", "Avg From Cubeo", "Updated"]
  end

  def uniq
    factions = []
    factionSystems = {}
    factionSpheres = {}
    @items.each do |item|
      factions.push item[:faction]
      if factionSystems[item[:faction]]
        factionSystems[item[:faction]].push item[:system]
      else
        factionSystems[item[:faction]] = [item[:system]]
      end
      if factionSpheres[item[:faction]]
        factionSpheres[item[:faction]].push item[:control_system]
      else
        factionSpheres[item[:faction]] = [item[:control_system]]
      end
    end
    @items = []
    factions.uniq!
    factions.each do |fac|
      factionSystems[fac].uniq!
      factionSpheres[fac].uniq!
      avg_from_cubeo = (factionSystems[fac].collect { |x| x["dist_to_cubeo"] }.reduce(:+) / factionSystems[fac].size.to_f).round(1)
      @items.push({faction: fac, systems: factionSystems[fac], spheres: factionSpheres[fac], avg_from_cubeo: avg_from_cubeo})
    end
  end

  def sort
    @items.sort_by! { |x| x[:avg_from_cubeo] }
  end
end

# Expected Item properties: control_system, profit, income, upkeep, overhead
class CCProfitDataSet < AislingDataSet
  def itemToString(item)
    return "#{link_to_system(item[:control_system])} | #{item[:profit]} CC | #{item[:income]} CC \
    | #{item[:upkeep]} CC | #{item[:overhead]} CC | #{item[:control_system]["dist_to_cubeo"]} LY"
  end

  def tableHeader
    return ["Control System", "Profit", "Income", "Upkeep", "Overhead", "From Cubeo"]
  end

  def sort
    @items.sort_by! { |x| [-x[:profit]] }
  end

  def filterText
    totalIncome = @items.reduce(0) { |sum, x| sum + x[:income] }.round(0)
    totalUpkeep = @items.reduce(0) { |sum, x| sum + x[:upkeep] }.round(0)
    totalOH = @items.reduce(0) { |sum, x| sum + x[:overhead] }.round(0)
    totalProfitNoFort = totalIncome - totalUpkeep - totalOH
    totalProfitFort = totalIncome - totalOH
    return "**Totals:** Income #{totalIncome} CC, Upkeep #{totalUpkeep} CC, Overheads #{totalOH} CC<br>Expected Profit (No fortification) #{totalProfitNoFort} CC<br>Expected Profit (Full fortification) #{totalProfitFort} CC"
  end
end

# Expected Item properties: control_system, upkeep
class CCUpkeepDataSet < AislingDataSet
  def itemToString(item)
    return "#{link_to_system(item[:control_system])} | #{item[:upkeep]} CC | #{item[:control_system]["dist_to_cubeo"]} LY"
  end

  def tableHeader
    return ["Control System", "Upkeep", "From Cubeo"]
  end

  def sort
    @items.sort_by! { |x| [-x[:upkeep]] }
  end
end

# Expected Item properties: control_system, income
class CCIncomeDataSet < AislingDataSet
  def itemToString(item)
    return "#{link_to_system(item[:control_system])} | #{item[:income]} CC | #{item[:control_system]["dist_to_cubeo"]} LY"
  end

  def tableHeader
    return ["Control System", "Income", "From Cubeo"]
  end

  def sort
    @items.sort_by! { |x| [-x[:income]] }
  end
end

# Expected Item properties: control_system, system, station, faction, priority
class StationDropDataSet < AislingDataSet
  def itemToString(item)
    return "#{item[:station]["name"]} | #{link_to_faction(item[:faction]["fac"])} | #{item[:faction]["active_states_names"].join(", ")} | #{link_to_system(item[:system])} | #{link_to_system(item[:control_system])} | #{(item[:station]["distanceToArrival"]).round(1)} Ls | #{item[:system]["dist_to_cubeo"]} LY"
  end

  def tableHeader
    return ["Station", "Faction", "States", "System", "Control System", "To Station", "From Cubeo"]
  end

  def sort
    @items.sort_by! { |x| [x[:priority], -x[:faction]["influence"]] }
  end
end
