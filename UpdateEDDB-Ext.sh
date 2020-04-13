#!/bin/bash
curl -s --compressed --header "Accept-Encoding: gzip, deflate, sdch" https://eddb.io/archive/v6/systems_populated.json > data/systems_populated.json
curl -s --compressed --header "Accept-Encoding: gzip, deflate, sdch" https://eddb.io/archive/v6/stations.json > data/stations.json
curl -s --compressed --header "Accept-Encoding: gzip, deflate, sdch" https://eddb.io/archive/v6/commodities.json > data/commodities.json
curl -s --compressed --header "Accept-Encoding: gzip, deflate, sdch" https://eddb.io/archive/v6/listings.csv > data/listings.csv
