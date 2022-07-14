#!/bin/bash -e
set -o pipefail
source env.sh
echo ">>> Export results as one GeoJSON file"

psql -t -v ON_ERROR_STOP=ON -f export_geojson.sql > data/landuse_without_buildings.left

# For some reason, the exported GeoJSON files do not follow the "right-hand
# rule" how to order the polygon nodes. Fix them using 'geojson-rewind'.
geojson-rewind data/landuse_without_buildings.left > data/landuse_without_buildings.geojson
