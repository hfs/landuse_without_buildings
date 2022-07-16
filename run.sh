#!/bin/bash -e
set -o pipefail

basedir=$(dirname "$BASH_SOURCE[0]")
cd "$basedir"

source env.sh
./01_download.sh
./02_createdb.sh
./03_import_osm.sh
./04_analyze.sh
./05_fetch_old_challenges.py
./06_import_old_challenges.sh
./07_subtract_old_challenges.sh
./08_export_csv.sh
./09_export_geojson.sh
