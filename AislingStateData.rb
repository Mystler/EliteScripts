# General helper Functions
def link_to_system(system)
  return "#{system['name']} <sup>[E](https://eddb.io/system/#{system['id']}){:target=\"_blank\"} [M](https://www.edsm.net/en/system/id/#{system['edsm_id']}/name/#{system['name']}){:target=\"_blank\"} [I](https://inara.cz/search/?location=search&searchglobal=#{system['name']}){:target=\"_blank\"}</sup>"
end

def link_to_faction(faction)
  return "#{faction['name']} <sup>[E](https://eddb.io/faction/#{faction['id']}){:target=\"_blank\"} [I](https://inara.cz/search/?location=search&searchglobal=#{faction['name']}){:target=\"_blank\"}</sup>"
end

def updated_at(el)
  time = Time.at(el['updated_at'])
  return "<u><em class=\"timeago\" datetime=\"#{time}\" data-toggle=\"tooltip\" title=\"#{time}\"></em></u>"
end

# Base class for reports.
# Only collecting strings as items and printing them in kramdown format.
# Override the private methods itemToString and sort when working with objects.
class AislingDataSet
  def initialize(title, icon = nil, description = nil)
    @title = title
    @icon = icon
    @description = description
    @items = []
    @table = nil
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

  def write(out, removeDuplicates = true)
    out.puts '<div class="card bg-darken" markdown="1">'
    svg = @icon ? "<img class=\"ad-icon\" alt=\"#{@icon}\" src=\"#{@icon}.svg\"> " : ''
    out.puts "### #{svg}#{@title}"
    out.puts '{:.card-header}'
    out.puts '<div class="card-body" markdown="1">'
    if @description
      out.puts "*#{@description}*"
      out.puts
    end

    @items.uniq! if removeDuplicates
    lines = compileLines()

    if @table && !lines.empty?
      out.puts '| ' + @table.join(" | ")
      out.puts '| -' * @table.size
    end
    lines.each do |line|
      out.puts "#{@table ? '|' : '-'} #{line}"
    end
    out.puts "{:.table .table-striped .table-borderless}" if @table && !lines.empty?
    out.puts 'NONE' if lines.empty?
    out.puts
    out.puts '<div class="text-right"><a href="#">Back to Top</a></div>'
    out.puts
    out.puts '</div></div>'
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

# Control System Flip State Data Set
# Expected Item properties: control_system, active_ccc, active_ccc_r, max_ccc, max_ccc_r, total_govs
# Added internally (should be in table header): dist_to_cubeo
class ControlSystemFlipStateDataSet < AislingDataSet
  def itemToString(item)
    active_percent = (100.0 * item[:active_ccc_r]).round(1)
    max_percent = (100.0 * item[:max_ccc_r]).round(1)
    return "#{link_to_faction(item[:control_system])} | #{item[:active_ccc]} (#{active_percent}%) | #{item[:max_ccc]} (#{max_percent}%) \
    | #{item[:total_govs]} | #{item[:control_system]['dist_to_cubeo']} LY"
  end

  def sort
    @items.sort! { |x, y| y[:active_ccc_r] <=> x[:active_ccc_r] }
  end
end

# Fav Push Factions Data Set
# Expected Item properties: faction, system, influence, control_system
# Added internally (should be in table header): dist_to_cubeo, updated_at
class FavPushFactionDataSet < AislingDataSet
  def itemToString(item)
    return "#{link_to_faction(item[:faction])} | #{link_to_system(item[:system])} | #{item[:influence].round(1)}% \
    | #{link_to_system(item[:control_system])} | #{item[:system]['dist_to_cubeo']} LY | #{updated_at(item[:system])}"
  end

  def sort
    @items.sort! { |x, y| y[:influence] <=> x[:influence] }
  end
end

# Warring CCCs Data Set
# Expected Item properties: faction, type, system, control_system
# Added internally (should be in table header): dist_to_cubeo, updated_at
class WarringCCCDataSet < AislingDataSet
  def itemToString(item)
    return "#{link_to_faction(item[:faction])} | #{item[:type]} | #{link_to_system(item[:system])} | \
    #{link_to_system(item[:control_system])} | #{item[:system]['dist_to_cubeo']} LY | #{updated_at(item[:system])}"
  end

  def sort
    @items.sort! { |x, y| x[:system]['dist_to_cubeo'] <=> y[:system]['dist_to_cubeo'] }
  end
end

# CC Profit Data Set
# Expected Item properties: control_system, profit, income, upkeep, overhead
# Added internally (should be in table header): dist_to_cubeo
class CCProfitDataSet < AislingDataSet
  def itemToString(item)
    return "#{link_to_system(item[:control_system])} | #{item[:profit]} CC | #{item[:income]} CC \
    | #{item[:upkeep]} CC | #{item[:overhead]} CC | #{item[:control_system]['dist_to_cubeo']} LY"
  end

  def sort
    @items.sort! { |x, y| y[:profit] <=> x[:profit] }
  end
end

# CC Income Data Set
# Expected Item properties: control_system, income
# Added internally (should be in table header): dist_to_cubeo
class CCIncomeDataSet < AislingDataSet
  def itemToString(item)
    return "#{link_to_system(item[:control_system])} | #{item[:income]} CC | #{item[:control_system]['dist_to_cubeo']} LY"
  end

  def sort
    @items.sort! { |x, y| y[:income] <=> x[:income] }
  end
end
