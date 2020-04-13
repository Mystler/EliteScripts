require_relative "PowerStateData"
require_relative "AislingStateConfig"

# Expected Item properties: control_system
class ControlSystemFlipStateDataSet < PowerDataSet
  def itemToString(item)
    active_percent = (100.0 * item[:control_system]["flip_data"][:active_ccc_r]).round(1)
    max_percent = (100.0 * item[:control_system]["flip_data"][:max_ccc_r]).round(1)
    return "#{link_to_system(item[:control_system])} | #{item[:control_system]["flip_data"][:active_ccc]} (#{active_percent}%) | #{item[:control_system]["flip_data"][:needed_ccc]} (#{item[:control_system]["flip_data"][:buffer_ccc]}) | #{item[:control_system]["flip_data"][:max_ccc]} (#{max_percent}%) \
    | #{item[:control_system]["flip_data"][:total_govs]} | #{item[:control_system]["fortPrioText"]} | #{item[:control_system]["dist_to_hq"]} LY"
  end

  def tableHeader
    return ["Control System", "CCC Governments", "Needed CCC Governments", "Possible CCC Governments", "Total Governments", "Fort Prio", "From HQ"]
  end

  def filter
    @items.reject! { |x| AislingStateConfig.blacklistCombined.include?(x[:control_system]["name"]) }
  end

  def filterText
    return AislingStateConfig.blacklistText
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
    | #{item[:control_system]["flip_data"][:total_govs]} | #{item[:control_system]["fortPrioText"]} | #{item[:control_system]["dist_to_hq"]} LY"
  end

  def tableHeader
    return ["Control System", "Priority", "CCC Governments", "Needed CCC Governments", "Possible CCC Governments", "Total Governments", "Fort Prio", "From HQ"]
  end

  def sort
    @items.sort_by! { |x| [x[:priority], x[:control_system]["flip_data"][:buffer_ccc].abs, -x[:control_system]["flip_data"][:active_ccc_r]] }
  end
end

# Expected Item properties: faction (in system object), system, control_system
class FavPushFactionDataSet < PowerDataSet
  def itemToString(item)
    return "#{link_to_faction(item[:faction])} | #{item[:faction]["states_output"]} | #{link_to_system(item[:system])} | #{(item[:faction]["influence"] * 100).round(1)}% \
    | #{link_to_system(item[:control_system])} | #{item[:control_system]["fortPrioText"]} | #{item[:system]["dist_to_hq"]} LY | #{updated_at(item[:system])}"
  end

  def tableHeader
    return ["Faction", "States", "System", "Influence", "Sphere", "Fort Prio", "From HQ", "Updated"]
  end

  def filter
    @items.reject! { |x| AislingStateConfig.blacklistCombined.include?(x[:control_system]["name"]) }
  end

  def filterText
    return AislingStateConfig.blacklistText
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
    #{item[:control_war]} | #{item[:ccc_flip_str]} | #{item[:control_system]["fortPrioText"]} | #{item[:system]["dist_to_hq"]} LY | #{updated_at(item[:system])}"
  end

  def tableHeader
    return ["Faction", "System", "Sphere", "States", "Control War", "Flip State", "Fort Prio", "From HQ", "Updated"]
  end

  def filter
    @items.reject! { |x| AislingStateConfig.blacklistCombined.include?(x[:control_system]["name"]) }
  end

  def filterText
    return AislingStateConfig.blacklistText
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
    return "#{link_to_system(item[:control_system])} | #{item[:control_system]["fortPrioText"]} | #{(item[:profit] - item[:control_system]["overlapped_systems_cc"]).round(1)} CC | #{item[:profit]} CC | #{item[:income] - item[:control_system]["overlapped_systems_cc"]} CC | #{item[:income]} CC \
    | #{item[:upkeep]} CC | #{item[:overhead]} CC | #{item[:control_system]["dist_to_hq"]} LY"
  end

  def tableHeader
    return ["Control System", "Fort Prio", "Effective Profit", "Full Profit", "Unique Income", "Income", "Upkeep", "Overhead", "From HQ"]
  end

  def sort
    @items.sort_by! { |x| [-(x[:profit] - x[:control_system]["overlapped_systems_cc"])] }
  end
end

# Expected Item properties: control_system, upkeep
class CCUpkeepDataSet < PowerDataSet
  def itemToString(item)
    return "#{link_to_system(item[:control_system])} | #{item[:control_system]["fortPrioText"]} | #{item[:upkeep]} CC | #{item[:control_system]["dist_to_hq"]} LY"
  end

  def tableHeader
    return ["Control System", "Fort Prio", "Upkeep", "From HQ"]
  end

  def sort
    @items.sort_by! { |x| [-x[:upkeep]] }
  end
end

# Expected Item properties: control_system, income
class CCIncomeDataSet < PowerDataSet
  def itemToString(item)
    return "#{link_to_system(item[:control_system])} | #{item[:control_system]["fortPrioText"]} | #{item[:income] - item[:control_system]["overlapped_systems_cc"]} CC | #{item[:income]} CC | #{item[:control_system]["overlapped_systems_no"]} | #{item[:control_system]["dist_to_hq"]} LY"
  end

  def tableHeader
    return ["Control System", "Fort Prio", "Unique Income", "Full Income", "Overlapped Systems", "From HQ"]
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
    return "#{link_to_system(item[:control_system])} | #{item[:control_system]["fortPrioText"]} | #{(item[:total_ccc_inf][:now] * 100).round(1)} | #{(item[:total_ccc_inf][:week] * 100).round(1)} | #{(item[:total_ccc_inf][:change_week] * 100).round(1)} | #{(item[:total_ccc_inf][:month] * 100).round(1)} | #{(item[:total_ccc_inf][:change_month] * 100).round(1)}"
  end

  def tableHeader
    return ["Control System", "Fort Prio", "Total CCC Inf", "Last Week", "Change", "Last Month", "Change"]
  end

  def sort
    @items.sort_by! { |x| [-x[:total_ccc_inf][:change_week].abs] }
  end
end

# Expected Item properties: control_system, system, faction, retreat_info, retreat_prio
class RetreatsDataSet < PowerDataSet
  def itemToString(item)
    return "#{link_to_faction(item[:faction])} | #{item[:faction]["allegiance"]} #{item[:faction]["government"]} | #{link_to_system(item[:system])} | \
    #{link_to_system(item[:control_system])} | #{item[:retreat_info]} | #{item[:control_system]["fortPrioText"]} | \
    #{item[:system]["dist_to_hq"]} LY | #{updated_at(item[:system])}"
  end

  def tableHeader
    return ["Faction", "Type", "System", "Sphere", "Retreat Class", "Fort Prio", "From HQ", "Updated"]
  end

  def filter
    @items.reject! { |x| AislingStateConfig.blacklistCombined.include?(x[:control_system]["name"]) }
  end

  def filterText
    return AislingStateConfig.blacklistText
  end

  def sort
    @items.sort_by! { |x| [x[:retreat_prio], x[:control_system]["flip_data"][:buffer_ccc].abs, x[:system]["dist_to_hq"]] }
  end
end
