#!/bin/bash -e

basedir=$(dirname "$BASH_SOURCE[0]")
cd "$basedir"

./01_download.sh
./02_createdb.sh
./03_import_census.sh
./04_import_osm.sh
./05_analyze.sh
./06_export_geojson.sh
