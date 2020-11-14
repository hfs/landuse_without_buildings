#!/bin/bash -e
source env.sh
echo ">>> Analyze OSM and census data"
psql -f unmapped_census.sql -ab
