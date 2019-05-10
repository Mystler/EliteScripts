require "csv"
require "clipboard"

# Sight Tracking
travelDist = 0
scans = {}
probes = {}

# Read and count data
CSV.foreach(ARGV[0], headers: true) do |row|
  # Get max travel distance if available
  if row["Travel Dist"] && row["Travel Dist"].to_f > travelDist
    travelDist = row["Travel Dist"].to_f
  end

  # Get scan and probe counts
  if row["Event"].start_with?("Detailed scan") || row["Event"].start_with?("Autoscan") && !row["Event"].include?("Belt Cluster")
    bodyType = row["Description"].split(",")[0]
    scans[bodyType] = scans[bodyType].to_i.next
  elsif row["Event"] == "SAA Scan Complete"
    mdata = /.*Probes:(\d+),.*/.match(row["Description"])
    proberange = case mdata[1].to_i
                 when 1..5
                   "1 to 5"
                 when 6..10
                   "6 to 10"
                 when 11..20
                   "11 to 20"
                 when 21..30
                   "21 to 30"
                 when 31..Float::INFINITY
                   "Over 30"
                 end
    probes[proberange] = probes[proberange].to_i.next
  end
end

puts "Prismatic Report"
puts "----------------"
puts

out = StringIO.new
out.puts "+#{travelDist} LY traveled"
scans.sort_by { |k, v| -v }.each do |body, scans|
  out.puts "+#{scans} scans of #{body}"
end
probes.sort_by { |k, v| -v }.each do |probecount, amount|
  out.puts "+#{amount} planets mapped with #{probecount} probes each"
end
puts out.string
Clipboard.copy out.string

puts
puts "Report has been copied to your clipboard!"
gets
