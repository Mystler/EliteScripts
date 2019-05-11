require "clipboard"
require_relative "lib/Interactive"
require_relative "lib/EliteJournal"

# User Prompts
starttime = Interactive.UserInputPrompt("Please enter your timespan (timestamps using the ISO 8601 standard).", "Start Time")
puts
endtime = Interactive.UserInputPrompt("Optional parameter, no value or 0 will process all data up to now.", "End Time")
puts
puts "Processing..."
puts
puts

# Sight Tracking Initialization
travelDist = 0
scans = {}
probes = {}

# Read and count data
EliteJournal.each(["Scan", "SAAScanComplete", "FSDJump"], starttime, endtime) do |entry|
  if entry["event"] == "FSDJump"
    travelDist += entry["JumpDist"]
  elsif entry["event"] == "SAAScanComplete"
    proberange = case entry["ProbesUsed"]
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
  elsif entry["event"] == "Scan" && ["Detailed", "Basic", "AutoScan"].include?(entry["ScanType"])
    next if entry["BodyName"].include?("Belt Cluster")
    if entry["StarType"]
      bodyType = entry["StarType"]
      if ["O", "B", "A", "F", "G", "K", "M", "L", "T", "Y", "TTS"].include?(bodyType)
        bodyType = "O, B, A, F, G, K, M, L, T, Y stars"
      end
      scans[bodyType] = scans[bodyType].to_i.next
    elsif entry["PlanetClass"]
      bodyType = entry["PlanetClass"]
      scans[bodyType] = scans[bodyType].to_i.next
    end
  end
end

puts "Prismatic Report"
puts "----------------"
puts

out = StringIO.new
out.puts "+#{travelDist.round(2)} LY traveled"
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
puts "Press enter to quit..."
Interactive.GetInputOrArg()
