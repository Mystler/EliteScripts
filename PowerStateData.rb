# Analyzation helpers
def is_conflicting(states)
  return (["civil war", "war"] & states.collect { |x| x.downcase }).any?
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

# Report helpers
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
  return "#{faction["name"]} <sup>[M](https://www.edsm.net/en/faction/id/#{faction["id"]}/name/#{faction["name"].gsub(" ", "+")}){:target=\"_blank\"} [I](https://inara.cz/search/?location=search&searchglobal=#{faction["name"]}){:target=\"_blank\"}</sup>"
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
