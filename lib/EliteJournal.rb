require "rubygems"
require "json"
require "time"
require_relative "Interactive"

class EliteJournal
  def self.path
    if Gem.win_platform?
      begin
        require 'win32/registry'
        reg_path = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders'
        reg = Win32::Registry::HKEY_CURRENT_USER.open(reg_path)
        save_path = reg['{4C5C32FF-BB9D-43B0-B5B4-2D72E54EAAA4}'] # Saved Games
        if save_path
          return "#{save_path}\\Frontier Developments\\Elite Dangerous"
        end
      rescue TypeError
        # NOOP
      end
    end
    custom_path = Interactive.UserInputPrompt("WARNING: Windows saved games folder not found. Please specify the ED Journal folder manually.", "ED Journal Folder")
    return custom_path
  end

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
    begin
      tstart = Time.parse(starttime)
      tend = Time.parse(endtime) if endtime
    rescue
      puts "ERROR: Could not parse entered date/time."
      puts "Press enter to quit!"
      Interactive.GetInputOrArg()
      exit
    end
    Dir.chdir(path) do
      Dir["Journal.*.log"].sort { |a, b| File.mtime(b) <=> File.mtime(a) }.each do |logfile|
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
