#!/bin/bash -e
set -o pipefail
source env.sh

#./wait_for_postgres.sh
echo ">>> Import old challenges into the database"
for file in data/challenge_*_tasks.geojson; do
	echo ">>>     $file"
	ogr2ogr -f "PostgreSQL" -lco GEOMETRY_NAME=geom \
		--config PG_USE_COPY YES -nln old_tasks -append \
		"PG:host=$PGHOST port=$PGPORT dbname=$PGDATABASE user=$PGUSER password=$PGPASSWORD" \
		$file
done
echo ">>> Done"
