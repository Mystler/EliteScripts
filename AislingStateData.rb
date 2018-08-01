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

# Fav Push Factions Data Set
# Expected Item properties: faction, system, influence, control_system
class FavPushFactionDataSet < AislingDataSet
  def itemToString(item)
    return "#{link_to_faction(item[:faction])} | #{link_to_system(item[:system])} | #{item[:influence].round(1)}% | #{link_to_system(item[:control_system])}"
  end

  def sort
    @items.sort! { |x, y| y[:influence] <=> x[:influence] }
  end
end

# CC Profit Data Set
# Expected Item properties: control_system, profit, income, upkeep, overhead
class CCProfitDataSet < AislingDataSet
  def itemToString(item)
    return "#{link_to_system(item[:control_system])} | #{item[:profit]} CC | #{item[:income]} CC | #{item[:upkeep]} CC | #{item[:overhead]} CC"
  end

  def sort
    @items.sort! { |x, y| y[:profit] <=> x[:profit] }
  end
end

# CC Income Data Set
# Expected Item properties: control_system, income
class CCIncomeDataSet < AislingDataSet
  def itemToString(item)
    return "#{link_to_system(item[:control_system])} | #{item[:income]} CC"
  end

  def sort
    @items.sort! { |x, y| y[:income] <=> x[:income] }
  end
end
