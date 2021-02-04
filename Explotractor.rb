require "rubygems"
require "bundler/setup"
require "clipboard"
require "stringio"
require_relative "lib/Interactive"
require_relative "lib/EliteJournal"

if defined?(Ocra)
  exit
end

puts "================"
puts "= Explotractor ="
puts "================"
puts
puts "Welcome, this will generate your personal scan, map, and travel report for the Prismatic Imperium, Branch of Sight."
puts

# User Prompts
starttime = Interactive.UserInputPrompt("Please enter your data timespan. (ISO 8601 format recommended, e.g. 2019-05-20 or 2019-05-20T12:34:56+2)", "Start Time")
puts
endtime = Interactive.UserInputPrompt("Optional parameter, no value or 0 will process all data up to now.", "End Time")
puts
puts "Processing..."
puts
puts

# Sight Tracking Initialization
scans = {}
probes = {}

# Failsafe track Bodies to exclude possible double scans after mapping
scannes_bodies = []

# Track binary/trinary/etc. systems by storing their highest star designation (B, C, D, ...)
systems_highest_star_letter = {}

# Read and count data
EliteJournal.each(["Scan", "SAAScanComplete", "FSDJump"], starttime, endtime) do |entry|
  if entry["event"] == "SAAScanComplete"
    proberange = case entry["EfficiencyTarget"]
                 when 2..5
                   "2 to 5"
                 when 6..12
                   "6 to 12"
                 when 13..18
                   "13 to 18"
                 when 19..22
                   "19 to 22"
                 when 23..Float::INFINITY
                   "Over 23"
                 else
                   nil
                 end
    probes[proberange] = probes[proberange].to_i.next if proberange
  elsif entry["event"] == "Scan" && ["Detailed", "Basic", "AutoScan"].include?(entry["ScanType"])
    next if entry["BodyName"].include?("Belt Cluster")
    next if scannes_bodies.include? entry["BodyName"]
    scannes_bodies.push entry["BodyName"]
    if entry["StarType"]
      # Star body type counting
      bodyType = entry["StarType"]
      if ["O", "B", "A", "F", "G", "K", "M"].include?(bodyType)
        bodyType = "Main Sequence Stars (O, B, A, F, G, K, M)"
      elsif ["L", "T", "Y"].include?(bodyType)
        bodyType = "Brown Dwarves (L, T, Y)"
      elsif ["TTS", "AeBe"].include?(bodyType)
        bodyType = "Proto (AeBe/T Tauri) stars"
      elsif ["W", "WN", "WNC", "WC", "WO"].include?(bodyType)
        bodyType = "Wolf-Rayet stars"
      elsif ["CS", "C", "CN", "CJ", "CH", "CHd", "MS", "S"].include?(bodyType)
        bodyType = "Carbon stars"
      elsif ["D", "DA", "DAB", "DAO", "DAZ", "DAV", "DB", "DBZ", "DBV", "DO", "DOV", "DQ", "DC", "DCV", "DX"].include?(bodyType)
        bodyType = "White dwarf stars"
      elsif ["A_BlueWhiteSuperGiant", "B_BlueWhiteSuperGiant", "F_WhiteSuperGiant", "M_RedSuperGiant", "M_RedGiant", "K_OrangeGiant"].include?(bodyType)
        bodyType = "Giant stars"
      elsif ["H", "SupermassiveBlackHole"].include?(bodyType)
        bodyType = "Black Holes"
      elsif ["N"].include?(bodyType)
        bodyType = "Neutron stars"
      end
      scans[bodyType] = scans[bodyType].to_i.next

      # Store highest main star designation
      if m_data = entry["BodyName"].match(/(.*) ([B-Z])\Z/)
        if (!systems_highest_star_letter[m_data[1]] || systems_highest_star_letter[m_data[1]] < m_data[2])
          systems_highest_star_letter[m_data[1]] = m_data[2]
        end
      end
    elsif entry["PlanetClass"]
      bodyType = entry["PlanetClass"]
      scans[bodyType] = scans[bodyType].to_i.next
    end
  end
end

multistar_system_counts = {}
# Post-process multi-stars systems
systems_highest_star_letter.each do |system, letter|
  name = case letter
         when "B"
           "binary systems"
         when "C"
           "trinary systems"
         when "D"
           "quaternary systems"
         when "E"
           "quinary systems"
         when "F"
           "senary systems"
         else
           "#{letter.ord - "A".ord + 1}-star systems"
         end
  multistar_system_counts[name] = multistar_system_counts[name].to_i.next
end

puts "Prismatic Report"
puts "----------------"
puts

out = StringIO.new
scans.sort_by { |k, v| -v }.each do |body, scans|
  out.puts "+#{scans} scans of #{body}"
end
multistar_system_counts.sort_by { |k, v| -v }.each do |system, amount|
  out.puts "+#{amount} #{system}"
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
