#!/bin/bash -e

cd data
echo ">>> Downloading OpenStreetMap dump for Germany"
wget 'http://download.geofabrik.de/europe/germany-latest.osm.pbf' \
    --timestamping
