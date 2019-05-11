require "json"
require "time"
require_relative "Interactive"

class EliteJournal
  # Events being nil will load all events, supply an array please!!!
  # Start and end time will be parsed from strings.
  def self.each(events, starttime, endtime = nil)
    endtime = nil if endtime&.empty? || endtime == "0"
    starttime = nil if starttime&.empty? || starttime == "0"
    if starttime == nil
      puts "ERROR: Please specify start time!"
      puts "Press enter to quit!"
      Interactive.GetInputOrArg()
      exit
    end
    tstart = Time.parse(starttime)
    tend = Time.parse(endtime) if endtime
    Dir.chdir("C:\\Users\\#{ENV["USERNAME"]}\\Saved Games\\Frontier Developments\\Elite Dangerous") do
      Dir["*.log"].sort { |a, b| File.mtime(b) <=> File.mtime(a) }.each do |logfile|
        # Sorted descending by last modification, so before start time means files are irrelevant now.
        return if File.mtime(logfile) < tstart

        File.foreach(logfile) do |line|
          jsonObj = JSON.parse(line)
          timestamp = Time.parse(jsonObj["timestamp"])
          next if endtime && timestamp > tend
          next if timestamp < tstart
          if events == nil || events.include?(jsonObj["event"])
            yield jsonObj
          end
        end
      end
    end
  end
end
