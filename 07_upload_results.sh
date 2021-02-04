#!/bin/bash -e

DATE=$(date -d @$(stat --format %Y data/germany-latest.osm.pbf) +%Y-%m-%d)

mv data/*.csv ../landuse_without_buildings_csv/
pushd ../landuse_without_buildings_csv/
git add -u
git commit -m "Update with data from $DATE"
git push
popd

mv data/*.geojson ../landuse_without_buildings_geojson/
pushd ../landuse_without_buildings_geojson/
git add -u
git commit -m "Update with data from $DATE"
git push
popd
