#!/bin/bash -e
set -o pipefail
source env.sh

cd data
echo ">>> Downloading OpenStreetMap dump for '$REGION_PATH'"
wget "https://download.geofabrik.de/$REGION_PATH-latest.osm.pbf" \
    --timestamping
