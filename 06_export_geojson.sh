#!/bin/bash -e
source env.sh
echo ">>> Export results as GeoJSON file"
psql -f export_geojson.sql -t > data/landuse_without_buildings.left
geojson-rewind data/landuse_without_buildings.left > data/landuse_without_buildings.geojson
