#!/bin/bash -e

source env.sh

cd data
echo ">>> Downloading OpenStreetMap dump for Germany"
wget "https://download.geofabrik.de/europe/$REGION-latest.osm.pbf" \
    --timestamping
