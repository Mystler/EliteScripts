require "rubygems"
require "bundler/setup"
require "listen"
require "json"
require "win32/sound"
require "win32/sapi5"
include Win32
require_relative "lib/EliteJournal"

if defined?(Ocra)
  exit
end

=begin
last_checked_journal = Time.now.to_s
journal_listener = Listen.to(EliteJournal.path, force_polling: true, latency: 1, only: [/Journal\..*\.log$/]) do |modified, added, removed|
  now = Time.now.to_s
  EliteJournal.each(["ShipTargeted"], last_checked_journal) do |entry|
    if entry["event"] == "ShipTargeted"
      if entry["PilotName_Localised"] && entry["PilotName_Localised"].include?("CMDR ")
        cmdr_name = entry["PilotName_Localised"].gsub("CMDR ", "")
        puts "#{Time.now.to_s}: Targeted #{cmdr_name}..."
        tts = SpVoice.new
        tts.Speak(cmdr_name)
      end
    end
  end
  last_checked_journal = now
end
=end

last_checked_epoch = 0
friendly_cmdr_freqs = {}
unknown_cmdr_freqs = {}
next_friendly_freq = 440.0
next_unknown_freq = 2093.12
freq_step = 1.059463
history_listener = Listen.to("#{ENV["LOCALAPPDATA"]}\\Frontier Developments\\Elite Dangerous\\CommanderHistory", force_polling: true, latency: 1) do |modified, added, removed|
  if modified.any?
    data = JSON.parse(File.read(modified[0]))

    new_entries = data["Interactions"].select { |x| x["Epoch"] > last_checked_epoch }
    new_entries = new_entries.first(1) if last_checked_epoch == 0
    new_entries.each do |entry|
      if entry["Interactions"].include?("WingMember")
        if !friendly_cmdr_freqs.has_key?(entry["CommanderID"])
          friendly_cmdr_freqs[entry["CommanderID"]] = next_friendly_freq
          next_friendly_freq = next_friendly_freq * freq_step
        end
        puts "#{Time.now.to_s}: Beeping change for #{entry["UserID"]}/#{entry["CommanderID"]} (Wing Mate)"
        Sound.beep(friendly_cmdr_freqs[entry["CommanderID"]], 400)
      else
        if !unknown_cmdr_freqs.has_key?(entry["CommanderID"])
          unknown_cmdr_freqs[entry["CommanderID"]] = next_unknown_freq
          next_unknown_freq = next_unknown_freq * freq_step
        end
        puts "#{Time.now.to_s}: Beeping change for #{entry["UserID"]}/#{entry["CommanderID"]}"
        Sound.beep(unknown_cmdr_freqs[entry["CommanderID"]], 200)
        Sound.beep(unknown_cmdr_freqs[entry["CommanderID"]], 200)
      end
    end

    last_checked_epoch = data["Interactions"].collect { |x| x["Epoch"] }.max
  end
end

#journal_listener.start
history_listener.start

puts "Running, press enter to quit..."
puts
gets

#journal_listener.stop
history_listener.stop
