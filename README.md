# Mystler's Scripts for Elite: Dangerous

Includes:
- AislingState: Simple Report Generator for Aisling Duval
- Explotractor: Extracts a (Primatic Imperium Sight) mission report from the Elite journals
  - Can be run as an interactive prompt (just run the script) or with console parameters.
  - Params: starttime and (optional) endtime, ISO 8601 format.
  - E.g.: `ruby Explotractor.rb 2019-05-09 2019-05-10` will generate a report with data from May 9, 2019 until May 10.
  - E.g.: `ruby Explotractor.rb 2019-05-11T01:00:00+2` will generate a report with data from May 11, 2019, 01:00:00 UTC+2 until now.
