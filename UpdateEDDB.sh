#!/bin/bash
curl -s --compressed --header "Accept-Encoding: gzip, deflate, sdch" https://eddb.io/archive/v5/systems_populated.json > data/systems_populated.json
curl -s --compressed --header "Accept-Encoding: gzip, deflate, sdch" https://eddb.io/archive/v5/factions.json > data/factions.json
