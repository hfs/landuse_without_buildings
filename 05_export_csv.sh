#!/bin/bash -e
source env.sh
echo ">>> Export results as CSV file"
psql -f export_csv.sql -t > data/landuse_without_buildings.csv
