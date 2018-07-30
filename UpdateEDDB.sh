#!/bin/bash
curl --compressed --header "Accept-Encoding: gzip, deflate, sdch" https://eddb.io/archive/v5/systems_populated.json > systems_populated.json
curl --compressed --header "Accept-Encoding: gzip, deflate, sdch" https://eddb.io/archive/v5/factions.json > factions.json
