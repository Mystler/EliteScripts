require "json"
require "time"

class EliteJournal
  # Events being nil will load all events, supply an array please!!!
  # Start and end time will be parsed from strings.
  def self.each(events, starttime, endtime = nil)
    tstart = Time.parse(starttime)
    tend = Time.parse(endtime) if endtime
    Dir.chdir("C:\\Users\\#{ENV["USERNAME"]}\\Saved Games\\Frontier Developments\\Elite Dangerous") do
      Dir["*.log"].each do |logfile|
        File.foreach(logfile) do |line|
          jsonObj = JSON.parse(line)
          timestamp = Time.parse(jsonObj["timestamp"])
          next if timestamp < tstart || (endtime && timestamp > tend)
          if events == nil || events.include?(jsonObj["event"])
            yield jsonObj
          end
        end
      end
    end
  end
end
