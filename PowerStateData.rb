# Report helpers
def str_to_id(str)
  gen_id = str.gsub(/^[^a-zA-Z]+/, "")
  gen_id.tr!("^a-zA-Z0-9 -", "")
  gen_id.tr!(" ", "-")
  gen_id.downcase!
  gen_id
end

def link_to_system(system)
  return "#{system["name"]} <sup>[E](https://eddb.io/system/factions/#{system["id"]}){:target=\"_blank\"} [M](https://www.edsm.net/en/system/id/#{system["edsm_id"]}/name/#{system["name"]}){:target=\"_blank\"} [I](https://inara.cz/search/?search=#{system["name"]}){:target=\"_blank\"}</sup>"
end

def link_to_faction(faction)
  return "#{faction["name"]} <sup>[M](https://www.edsm.net/en/faction/id/#{faction["id"]}/name/#{faction["name"].gsub(" ", "+")}){:target=\"_blank\"} [I](https://inara.cz/search/?search=#{faction["name"]}){:target=\"_blank\"}</sup>"
end

def updated_at(el)
  time = Time.at(el["updated_at"])
  colorclass = "age-green"
  if time < LastBGSTick - 172800
    colorclass = "age-red" # Last tick minus 2, so 3 ticks old
  elsif time < LastBGSTick
    colorclass = "age-yellow"
  end
  return "<u><em class=\"timeago #{colorclass}\" datetime=\"#{time}\" data-toggle=\"tooltip\" title=\"#{time}\"></em></u>"
end

# Base class for reports.
# Only collecting strings as items and printing them in kramdown format.
# Override the private methods when working with objects. Preprocessing order is filter, uniq, sort.
class PowerDataSet
  attr_accessor :description

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
    svg = @icon ? "<img class=\"card-icon\" alt=\"#{@icon}\" src=\"#{@icon}.svg\"> " : ""
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
      out.puts "{:.table .table-borderless}"
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

# Expected Item properties: control_system
class ControlSystemFlipStateDataSet < PowerDataSet
  def itemToString(item)
    active_percent = (100.0 * item[:control_system]["flip_data"][:active_ccc_r]).round(1)
    max_percent = (100.0 * item[:control_system]["flip_data"][:max_ccc_r]).round(1)
    return "#{link_to_system(item[:control_system])} | #{item[:control_system]["flip_data"][:active_ccc]} (#{active_percent}%) | #{item[:control_system]["flip_data"][:needed_ccc]} (#{item[:control_system]["flip_data"][:buffer_ccc]}) | #{item[:control_system]["flip_data"][:max_ccc]} (#{max_percent}%) \
    | #{item[:control_system]["flip_data"][:total_govs]} | #{item[:control_system]["fortPrioText"] + " |" if defined?(AislingStateConfig)} #{item[:control_system]["dist_to_hq"]} LY"
  end

  def tableHeader
    header = ["Control System", "Fav Governments", "Needed Fav Governments", "Possible Fav Governments", "Total Governments", "From HQ"]
    header.insert(-2, "Fort Prio") if defined?(AislingStateConfig)
    return header
  end

  def filter
    @items.reject! { |x| x[:control_system]["name"] == PowerData.headquarters }
    if defined?(AislingStateConfig)
      @items.reject! { |x| AislingStateConfig.blacklistCombined.include?(x[:control_system]["name"]) }
    end
  end

  def filterText
    if defined?(AislingStateConfig)
      return AislingStateConfig.blacklistText
    end
    return nil
  end

  def sort
    @items.sort_by! { |x| [x[:control_system]["flip_data"][:buffer_ccc].abs, -x[:control_system]["flip_data"][:active_ccc_r]] }
  end
end

class SimpleControlSystemFlipStateDataSet < PowerDataSet
  def itemToString(item)
    active_percent = (100.0 * item[:control_system]["flip_data"][:active_ccc_r]).round(1)
    max_percent = (100.0 * item[:control_system]["flip_data"][:max_ccc_r]).round(1)
    priority = (item[:priority] == 1 ? "Top" : (item[:priority] == 2 ? "High" : "Low"))
    return "#{link_to_system(item[:control_system])} | #{priority} | #{item[:control_system]["flip_data"][:active_ccc]} (#{active_percent}%) | #{item[:control_system]["flip_data"][:needed_ccc]} (#{item[:control_system]["flip_data"][:buffer_ccc]}) | #{item[:control_system]["flip_data"][:max_ccc]} (#{max_percent}%) \
    | #{item[:control_system]["flip_data"][:total_govs]} | #{item[:control_system]["fortPrioText"] + " |" if defined?(AislingStateConfig)} #{item[:control_system]["dist_to_hq"]} LY"
  end

  def tableHeader
    header = ["Control System", "Priority", "Fav Governments", "Needed Fav Governments", "Possible Fav Governments", "Total Governments", "From HQ"]
    header.insert(-2, "Fort Prio") if defined?(AislingStateConfig)
    return header
  end

  def sort
    @items.sort_by! { |x| [x[:priority], x[:control_system]["flip_data"][:buffer_ccc].abs, -x[:control_system]["flip_data"][:active_ccc_r]] }
  end
end

# Expected Item properties: faction (in system object), system, control_system
class FavPushFactionDataSet < PowerDataSet
  def itemToString(item)
    return "#{link_to_faction(item[:faction])} | #{item[:faction]["states_output"]} | #{link_to_system(item[:system])} | #{(item[:faction]["influence"] * 100).round(1)}% \
    | #{link_to_system(item[:control_system])} | #{item[:control_system]["fortPrioText"] + " |" if defined?(AislingStateConfig)} #{item[:system]["dist_to_hq"]} LY | #{updated_at(item[:system])}"
  end

  def tableHeader
    header = ["Faction", "States", "System", "Influence", "Sphere", "From HQ", "Updated"]
    header.insert(-3, "Fort Prio") if defined?(AislingStateConfig)
    return header
  end

  def filter
    @items.reject! { |x| x[:control_system]["name"] == PowerData.headquarters }
    if defined?(AislingStateConfig)
      @items.reject! { |x| AislingStateConfig.blacklistCombined.include?(x[:control_system]["name"]) }
    end
  end

  def filterText
    if defined?(AislingStateConfig)
      return AislingStateConfig.blacklistText
    end
    return nil
  end

  def sort
    @items.sort_by! { |x| [x[:control_system]["flip_data"][:buffer_ccc].abs, -x[:control_system]["flip_data"][:active_ccc_r], x[:control_system]["dist_to_hq"], -x[:faction]["influence"]] }
  end
end

class SimpleFavPushFactionDataSet < FavPushFactionDataSet
  def filterText
    return nil
  end

  def filter
  end

  def sort
    @items.sort_by! { |x| [x[:priority], x[:control_system]["flip_data"][:buffer_ccc].abs, -x[:control_system]["flip_data"][:active_ccc_r], x[:control_system]["dist_to_hq"], -x[:faction]["influence"]] }
  end
end

# Expected Item properties: faction (in system object), system, control_system
class WarringCCCDataSet < PowerDataSet
  def itemToString(item)
    return "#{link_to_faction(item[:faction])} | #{link_to_system(item[:system])} | \
    #{link_to_system(item[:control_system])} | #{item[:faction]["states_output"]} | \
    #{item[:control_war]} | #{item[:ccc_flip_str]} | #{item[:control_system]["fortPrioText"] + " |" if defined?(AislingStateConfig)} #{item[:system]["dist_to_hq"]} LY | #{updated_at(item[:system])}"
  end

  def tableHeader
    header = ["Faction", "System", "Sphere", "States", "Control War", "Flip State", "From HQ", "Updated"]
    header.insert(-3, "Fort Prio") if defined?(AislingStateConfig)
    return header
  end

  def filter
    @items.reject! { |x| x[:control_system]["name"] == PowerData.headquarters }
    if defined?(AislingStateConfig)
      @items.reject! { |x| AislingStateConfig.blacklistCombined.include?(x[:control_system]["name"]) }
    end
  end

  def filterText
    if defined?(AislingStateConfig)
      return AislingStateConfig.blacklistText
    end
    return nil
  end

  def sort
    @items.each do |x|
      if x[:control_war] == "Attacking"
        x[:ccc_flip_str] = x[:control_system]["flip_data"][:buffer_ccc] == -1 ? "Flip" : x[:control_system]["flip_data"][:buffer_ccc] >= 0 ? "#{x[:control_system]["flip_data"][:buffer_ccc] + 1} banking" : "#{-x[:control_system]["flip_data"][:buffer_ccc]} needed"
        x[:ccc_flip_sort] = 0
      elsif x[:control_war] == "Defending"
        x[:ccc_flip_str] = x[:control_system]["flip_data"][:buffer_ccc] == 0 ? "Unflip" : x[:control_system]["flip_data"][:buffer_ccc] > 0 ? "#{x[:control_system]["flip_data"][:buffer_ccc]} buffer" : "#{-x[:control_system]["flip_data"][:buffer_ccc]} needed"
        x[:ccc_flip_sort] = 0
      elsif x[:control_war] == "???"
        x[:ccc_flip_str] = x[:control_system]["flip_data"][:buffer_ccc] >= 0 ? "#{x[:control_system]["flip_data"][:buffer_ccc]} buffer" : "#{-x[:control_system]["flip_data"][:buffer_ccc]} needed"
        x[:ccc_flip_sort] = 0
      else
        x[:ccc_flip_str] = x[:control_system]["flip_data"][:buffer_ccc] >= 0 ? "#{x[:control_system]["flip_data"][:buffer_ccc]} buffer" : "#{-x[:control_system]["flip_data"][:buffer_ccc]} needed"
        x[:ccc_flip_sort] = 1
      end
    end
    @items.sort_by! { |x| [x[:ccc_flip_sort], x[:control_system]["flip_data"][:buffer_ccc].abs, -x[:control_war].ord, x[:system]["dist_to_hq"]] }
  end
end

class SimpleWarringCCCDataSet < WarringCCCDataSet
  def filterText
    return nil
  end

  def filter
  end

  def sort
    super
    @items.sort_by! { |x| [x[:priority], x[:ccc_flip_sort], x[:control_system]["flip_data"][:buffer_ccc].abs, -x[:control_war].ord, x[:system]["dist_to_hq"]] }
  end
end

# Expected Item properties: control_system, profit, income, upkeep, overhead
class CCProfitDataSet < PowerDataSet
  def itemToString(item)
    return "#{link_to_system(item[:control_system])} | #{item[:control_system]["fortPrioText"] + " |" if defined?(AislingStateConfig)} #{(item[:profit] - item[:control_system]["overlapped_systems_cc"]).round(1)} CC | #{item[:profit]} CC | #{item[:income] - item[:control_system]["overlapped_systems_cc"]} CC | #{item[:income]} CC \
    | #{item[:upkeep]} CC | #{item[:overhead]} CC | #{item[:control_system]["dist_to_hq"]} LY"
  end

  def tableHeader
    header = ["Control System", "Effective Profit", "Full Profit", "Unique Income", "Income", "Upkeep", "Overhead", "From HQ"]
    header.insert(1, "Fort Prio") if defined?(AislingStateConfig)
    return header
  end

  def sort
    @items.sort_by! { |x| [-(x[:profit] - x[:control_system]["overlapped_systems_cc"])] }
  end
end

# Expected Item properties: control_system, upkeep
class CCUpkeepDataSet < PowerDataSet
  def itemToString(item)
    return "#{link_to_system(item[:control_system])} | #{item[:control_system]["fortPrioText"] + " |" if defined?(AislingStateConfig)} #{item[:upkeep]} CC | #{item[:control_system]["dist_to_hq"]} LY"
  end

  def tableHeader
    header = ["Control System", "Upkeep", "From HQ"]
    header.insert(1, "Fort Prio") if defined?(AislingStateConfig)
    return header
  end

  def sort
    @items.sort_by! { |x| [-x[:upkeep]] }
  end
end

# Expected Item properties: control_system, income
class CCIncomeDataSet < PowerDataSet
  def itemToString(item)
    return "#{link_to_system(item[:control_system])} | #{item[:control_system]["fortPrioText"] + " |" if defined?(AislingStateConfig)} #{item[:income] - item[:control_system]["overlapped_systems_cc"]} CC | #{item[:income]} CC | #{item[:control_system]["overlapped_systems_no"]} | #{item[:control_system]["dist_to_hq"]} LY"
  end

  def tableHeader
    header = ["Control System", "Unique Income", "Full Income", "Overlapped Systems", "From HQ"]
    header.insert(1, "Fort Prio") if defined?(AislingStateConfig)
    return header
  end

  def sort
    @items.sort_by! { |x| [-(x[:income] - x[:control_system]["overlapped_systems_cc"])] }
  end
end

# Expected Item properties: control_system, system, station, faction, priority
class StationDropDataSet < PowerDataSet
  def itemToString(item)
    return "#{item[:station]["name"]} | #{link_to_faction(item[:faction])} | #{item[:faction]["states_output"]} | #{link_to_system(item[:system])} | #{link_to_system(item[:control_system])} | #{(item[:station]["distanceToArrival"]).round(1)} Ls | #{item[:system]["dist_to_hq"]} LY"
  end

  def tableHeader
    return ["Station", "Faction", "States", "System", "Control System", "To Station", "From HQ"]
  end

  def sort
    @items.sort_by! { |x| [x[:priority], -x[:faction]["influence"]] }
  end
end

# Expected Item properties: control_system, total_ccc_inf
class TopCCCInfMovements < PowerDataSet
  def itemToString(item)
    return "#{link_to_system(item[:control_system])} | #{item[:control_system]["fortPrioText"] + " |" if defined?(AislingStateConfig)} #{(item[:total_ccc_inf][:now] * 100).round(1)} | #{(item[:total_ccc_inf][:week] * 100).round(1)} | #{(item[:total_ccc_inf][:change_week] * 100).round(1)} | #{(item[:total_ccc_inf][:month] * 100).round(1)} | #{(item[:total_ccc_inf][:change_month] * 100).round(1)}"
  end

  def tableHeader
    header = ["Control System", "Total CCC Inf", "Last Week", "Change", "Last Month", "Change"]
    header.insert(1, "Fort Prio") if defined?(AislingStateConfig)
    return header
  end

  def sort
    @items.sort_by! { |x| [-x[:total_ccc_inf][:change_week].abs] }
  end
end

# Expected Item properties: control_system, system, faction, retreat_info, retreat_prio
class RetreatsDataSet < PowerDataSet
  def itemToString(item)
    return "#{link_to_faction(item[:faction])} | #{item[:faction]["allegiance"]} #{item[:faction]["government"]} | #{link_to_system(item[:system])} | \
    #{link_to_system(item[:control_system])} | #{item[:retreat_info]} | #{item[:control_system]["fortPrioText"] + " |" if defined?(AislingStateConfig)} \
    #{item[:system]["dist_to_hq"]} LY | #{updated_at(item[:system])}"
  end

  def tableHeader
    header = ["Faction", "Type", "System", "Sphere", "Retreat Class", "From HQ", "Updated"]
    header.insert(-3, "Fort Prio") if defined?(AislingStateConfig)
    return header
  end

  def filter
    @items.reject! { |x| x[:control_system]["name"] == PowerData.headquarters }
    if defined?(AislingStateConfig)
      @items.reject! { |x| AislingStateConfig.blacklistCombined.include?(x[:control_system]["name"]) }
    end
  end

  def filterText
    if defined?(AislingStateConfig)
      return AislingStateConfig.blacklistText
    end
    return nil
  end

  def sort
    @items.sort_by! { |x| [x[:retreat_prio], x[:control_system]["flip_data"][:buffer_ccc].abs, x[:system]["dist_to_hq"]] }
  end
end

class FavFacDefenseDataSet < PowerDataSet
  def itemToString(item)
    return "#{link_to_faction(item[:faction])} | #{item[:faction]["states_output"]} | #{link_to_system(item[:system])} | #{(item[:faction]["influence"] * 100).round(1)}% \
    | #{(item[:influence_lead] * 100).round(1)}% | #{link_to_system(item[:control_system])} | #{item[:control_system]["flip_data"][:buffer_ccc]} | \
    #{item[:control_system]["fortPrioText"] + " |" if defined?(AislingStateConfig)} #{item[:system]["dist_to_hq"]} LY | #{updated_at(item[:system])}"
  end

  def tableHeader
    header = ["Faction", "States", "System", "Influence", "Lead", "Sphere", "Flip Buffer", "From HQ", "Updated"]
    header.insert(-3, "Fort Prio") if defined?(AislingStateConfig)
    return header
  end

  def filter
    @items.reject! { |x| x[:influence_lead].abs > 0.2 }
    @items.reject! { |x| x[:control_system]["name"] == PowerData.headquarters }
    if defined?(AislingStateConfig)
      @items.reject! { |x| AislingStateConfig.blacklistCombined.include?(x[:control_system]["name"]) }
    end
  end

  def filterText
    if defined?(AislingStateConfig)
      return AislingStateConfig.blacklistText
    end
    return nil
  end

  def sort
    @items.sort_by! { |x| [x[:influence_lead], x[:control_system]["fortPrio"]] }
  end
end

class SimpleFavFacDefenseDataSet < FavFacDefenseDataSet
  def filterText
    return nil
  end

  def filter
    @items.reject! { |x| x[:influence_lead].abs > 0.2 }
  end

  def sort
    @items.sort_by! { |x| [x[:priority], x[:influence_lead], x[:control_system]["fortPrio"]] }
  end
end
