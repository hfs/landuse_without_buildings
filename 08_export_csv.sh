#!/bin/bash -e
set -o pipefail
source env.sh
echo ">>> Export results as CSV file"
psql -f export_csv.sql -t -v ON_ERROR_STOP=ON > data/landuse_without_buildings.csv
