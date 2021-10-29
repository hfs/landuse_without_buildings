#!/bin/bash -e
set -o pipefail

DATE=$(date -d @$(stat --format %Y data/germany-latest.osm.pbf) +%Y-%m-%d)

mv -f data/landuse_*.csv ../landuse_without_buildings_csv/
pushd ../landuse_without_buildings_csv/
git add -u
git commit -m "Update with data from $DATE"
git push
popd

mv -f data/landuse_*.geojson ../landuse_without_buildings_geojson/
pushd ../landuse_without_buildings_geojson/
git add -u
git commit -m "Update with data from $DATE"
git push
popd
