#!/bin/bash -e
set -o pipefail
source env.sh
echo ">>> Export results as GeoJSON file"
psql -f export_geojson.sql -t -v ON_ERROR_STOP=ON > data/landuse_without_buildings.left
geojson-rewind data/landuse_without_buildings.left > data/landuse_without_buildings.geojson
