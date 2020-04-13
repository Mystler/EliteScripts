require_relative "PowerStateData"
require_relative "WintersStateConfig"

# Expected Item properties: control_system
class ControlSystemFlipStateDataSet < PowerDataSet
  def itemToString(item)
    active_percent = (100.0 * item[:control_system]["flip_data"][:active_ccc_r]).round(1)
    max_percent = (100.0 * item[:control_system]["flip_data"][:max_ccc_r]).round(1)
    return "#{link_to_system(item[:control_system])} | #{item[:control_system]["flip_data"][:active_ccc]} (#{active_percent}%) | #{item[:control_system]["flip_data"][:needed_ccc]} (#{item[:control_system]["flip_data"][:buffer_ccc]}) | #{item[:control_system]["flip_data"][:max_ccc]} (#{max_percent}%) \
    | #{item[:control_system]["flip_data"][:total_govs]} | #{item[:control_system]["dist_to_hq"]} LY"
  end

  def tableHeader
    return ["Control System", "CCC Governments", "Needed CCC Governments", "Possible CCC Governments", "Total Governments", "From HQ"]
  end

  def filter
    @items.reject! { |x| WintersStateConfig.blacklistCombined.include?(x[:control_system]["name"]) }
  end

  def sort
    @items.sort_by! { |x| [x[:control_system]["flip_data"][:buffer_ccc].abs, -x[:control_system]["flip_data"][:active_ccc_r]] }
  end
end

# Expected Item properties: faction (in system object), system, control_system
class WarringCCCDataSet < PowerDataSet
  def itemToString(item)
    return "#{link_to_faction(item[:faction])} | #{link_to_system(item[:system])} | \
    #{link_to_system(item[:control_system])} | #{item[:faction]["states_output"]} | \
    #{item[:control_war]} | #{item[:ccc_flip_str]} | #{item[:system]["dist_to_hq"]} LY | #{updated_at(item[:system])}"
  end

  def tableHeader
    return ["Faction", "System", "Sphere", "States", "Control War", "Flip State", "From HQ", "Updated"]
  end

  def filter
    @items.reject! { |x| WintersStateConfig.blacklistCombined.include?(x[:control_system]["name"]) }
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

# Expected Item properties: control_system, profit, income, upkeep, overhead
class CCProfitDataSet < PowerDataSet
  def itemToString(item)
    return "#{link_to_system(item[:control_system])} | #{(item[:profit] - item[:control_system]["overlapped_systems_cc"]).round(1)} CC | #{item[:profit]} CC | #{item[:income] - item[:control_system]["overlapped_systems_cc"]} CC | #{item[:income]} CC \
    | #{item[:upkeep]} CC | #{item[:overhead]} CC | #{item[:control_system]["dist_to_hq"]} LY"
  end

  def tableHeader
    return ["Control System", "Effective Profit", "Full Profit", "Unique Income", "Income", "Upkeep", "Overhead", "From HQ"]
  end

  def sort
    @items.sort_by! { |x| [-(x[:profit] - x[:control_system]["overlapped_systems_cc"])] }
  end
end

# Expected Item properties: control_system, upkeep
class CCUpkeepDataSet < PowerDataSet
  def itemToString(item)
    return "#{link_to_system(item[:control_system])} | #{item[:upkeep]} CC | #{item[:control_system]["dist_to_hq"]} LY"
  end

  def tableHeader
    return ["Control System", "Upkeep", "From HQ"]
  end

  def sort
    @items.sort_by! { |x| [-x[:upkeep]] }
  end
end

# Expected Item properties: control_system, income
class CCIncomeDataSet < PowerDataSet
  def itemToString(item)
    return "#{link_to_system(item[:control_system])} | #{item[:income] - item[:control_system]["overlapped_systems_cc"]} CC | #{item[:income]} CC | #{item[:control_system]["overlapped_systems_no"]} | #{item[:control_system]["dist_to_hq"]} LY"
  end

  def tableHeader
    return ["Control System", "Unique Income", "Full Income", "Overlapped Systems", "From HQ"]
  end

  def sort
    @items.sort_by! { |x| [-(x[:income] - x[:control_system]["overlapped_systems_cc"])] }
  end
end
