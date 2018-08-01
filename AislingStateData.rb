# General helper Functions
def link_to_system(system)
  return "#{system['name']} <sup>[E](https://eddb.io/system/#{system['id']}){:target=\"_blank\"} [M](https://www.edsm.net/en/system/id/#{system['edsm_id']}/name/#{system['name']}){:target=\"_blank\"} [I](https://inara.cz/search/?location=search&searchglobal=#{system['name']}){:target=\"_blank\"}</sup>"
end

def link_to_faction(faction)
  return "#{faction['name']} <sup>[E](https://eddb.io/faction/#{faction['id']}){:target=\"_blank\"} [I](https://inara.cz/search/?location=search&searchglobal=#{faction['name']}){:target=\"_blank\"}</sup>"
end

# Base class for reports.
# Only collecting strings as items and printing them in kramdown format.
# Override the private methods itemToString and sort when working with objects.
class AislingDataSet
  def initialize(title, description = nil)
    @title = title
    @description = description
    @items = []
  end

  def addItem(item)
    @items.push item
  end

  def addItems(items)
    @items += items
  end

  def write(out, removeDuplicates = true)
    out.puts "### #{@title}"
    if @description
      out.puts "*#{@description}*"
      out.puts
    end
    @items.uniq! if removeDuplicates
    lines = compileLines()
    lines.each do |line|
      out.puts "- #{line}"
    end
    out.puts 'NONE' if lines.empty?
    out.puts
    out.puts '[To Top](#)'
    out.puts
  end

  private

  def compileLines
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

  def sort
    @items.sort!
  end
end

# Fav Push Factions Data Set
# Expected Item properties: faction, system, influence, control_system
class FavPushFactionDataSet < AislingDataSet
  def itemToString(item)
    return "#{link_to_faction(item[:faction])} in #{link_to_system(item[:system])} (#{item[:influence].round(1)}%) for Control System #{link_to_system(item[:control_system])}"
  end

  def sort
    @items.sort! { |x, y| y[:influence] <=> x[:influence] }
  end
end

# CC Profit Data Set
# Expected Item properties: control_system, profit, income, upkeep, overhead
class CCProfitDataSet < AislingDataSet
  def itemToString(item)
    return "#{link_to_system(item[:control_system])} has a radius profit of #{item[:profit]} CC (Income: #{item[:income]}, Upkeep: #{item[:upkeep]}, Overhead: #{item[:overhead]})"
  end

  def sort
    @items.sort! { |x, y| y[:profit] <=> x[:profit] }
  end
end

# CC Income Data Set
# Expected Item properties: control_system, income
class CCIncomeDataSet < AislingDataSet
  def itemToString(item)
    return "#{link_to_system(item[:control_system])} has a radius income of #{item[:income]} CC"
  end

  def sort
    @items.sort! { |x, y| y[:income] <=> x[:income] }
  end
end
