require "csv"
require "json"
require "matrix"

systems = JSON.parse(File.read("data/systems_populated.json"))
stations = JSON.parse(File.read("data/stations.json"))
commodities = JSON.parse(File.read("data/commodities.json"))

target_system = systems.find { |x| x["name"] == "Giguen" }
target_station = stations.find { |x| x["system_id"] == target_system["id"] && x["name"] == "Henry Dock" }
target_market = {}

systems.each do |sys|
  sys["location"] = Vector[sys["x"], sys["y"], sys["z"]]
end
systems.select! { |x| (x["location"] - target_system["location"]).r < 50 && x["id"] != target_system["id"] }
stations.select! { |x| systems.find { |y| y["id"] == x["system_id"] } }

best_buys = {}
CSV.foreach("data/listings.csv", headers: true, converters: :numeric) do |row|
  if row["station_id"] == target_station["id"] && row["sell_price"] > 0
    target_market[row["commodity_id"]] = row["sell_price"]
  elsif row["station_id"] != target_station["id"] && row["buy_price"] > 0 && row["supply"] > 1000
    station = stations.find { |x| x["id"] == row["station_id"] }
    if station #in range
      if !best_buys[row["commodity_id"]] || row["buy_price"] > best_buys[row["commodity_id"]]["buy_price"]
        system = systems.find { |x| x["id"] == station["system_id"] }
        best_buys[row["commodity_id"]] = {
          "station" => station["name"],
          "system" => system["name"],
          "buy_price" => row["buy_price"],
          "distance" => (system["location"] - target_system["location"]).r.round(2),
        }
      end
    end
  end
end

best_buys.reject! { |cid, trade| !target_market[cid] }
best_buys.each do |cid, trade|
  trade["sell_price"] = target_market[cid]
  trade["profit"] = target_market[cid] - trade["buy_price"]
end
best_buys.reject! { |cid, trade| trade[profit] >= 0 }

best_buys = best_buys.sort_by { |cid, x| [x["profit"]] }
best_buys.each do |cid, trade|
  commodity = commodities.find { |x| x["id"] == cid }
  puts "Buy #{commodity["name"]} at #{trade["station"]} in #{trade["system"]} (#{trade["distance"]} LY) for #{trade["buy_price"]}, sell #{trade["sell_price"]} (#{trade["profit"]})"
end
