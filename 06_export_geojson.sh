#!/bin/bash -e
source env.sh
echo ">>> Export results as GeoJSON file"
psql -f export_geojson.sql -t > data/unmapped_census.geojson
geojson-rewind data/unmapped_census.geojson > data/unmapped_census_fixed.geojson
