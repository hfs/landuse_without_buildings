#!/bin/bash -e
source env.sh
echo ">>> Analyze OSM landuse data"
psql -f landuse_without_buildings.sql -ab -v ON_ERROR_STOP=ON | ts '%Y-%m-%dT%H:%M:%S   '
