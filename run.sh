#!/bin/bash -e
set -o pipefail

basedir=$(dirname "$BASH_SOURCE[0]")
cd "$basedir"

./01_download.sh
./02_createdb.sh
./03_import_osm.sh
./04_analyze.sh
./05_export_csv.sh
./06_export_geojson.sh
