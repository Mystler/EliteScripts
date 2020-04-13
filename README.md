# Mystler's Scripts for Elite: Dangerous

Includes:
- PowerState: Report Generator for Powerplay
- Explotractor: Extracts a (Primatic Imperium Sight) mission report from the Elite journals
  - Can be run as an interactive prompt (just run the script) or with console parameters.
  - Params: starttime and (optional) endtime, ISO 8601 format.
  - E.g.: `ruby Explotractor.rb 2019-05-09 2019-05-10` will generate a report with data from May 9, 2019 until May 10.
  - E.g.: `ruby Explotractor.rb 2019-05-11T01:00:00+2` will generate a report with data from May 11, 2019, 01:00:00 UTC+2 until now.
- BeepBeep: Run while playing Elite. Plays sounds whenever there is a change in the contacts history.
  - Lower single notes: Change for an active or former Wing mate (assumed friendly)
  - High double notes: Change for an unknown, potentially hostile CMDR
