#!/bin/bash -e
set -o pipefail
source env.sh
echo ">>> Export results as one GeoJSON file per state"

export_geojson() {
	cat <<-EOF
		SELECT json_build_object(
			'type', 'FeatureCollection',
			'features', json_agg(ST_AsGeoJSON(u.*)::json)
		)
		FROM (
			SELECT
				id,
				osm_id,
				ROUND(area) AS area,
				ROUND(building_fraction::numeric, 4) AS building_fraction,
				-- No idea why ForceRHR doesn't help
				ST_ForceRHR(ST_Transform(geom, 4326)) AS geom
			FROM landuse_split
			WHERE
				building_fraction <= 0.05
				$@
			ORDER BY id
		) u
		;
	EOF
}

sql() {
	psql -t -v ON_ERROR_STOP=ON "$@"
}

export_geojson "AND state IN ('Berlin', 'Bremen', 'Hamburg', 'Saarland')" | sql > data/Berlin+Bremen+Hamburg+Saarland.left

for state in Baden-Württemberg Bayern Brandenburg Hessen Mecklenburg-Vorpommern Niedersachsen Nordrhein-Westfalen Rheinland-Pfalz Sachsen Sachsen-Anhalt Schleswig-Holstein Thüringen
do
	export_geojson "AND state = '$state'" | sql > data/$state.left
done

# For some reason, the exported GeoJSON files do not follow the "right-hand
# rule" how to order the polygon nodes. Fix them using 'geojson-rewind'.
for file in data/*.left; do
	geojson-rewind "$file" > "${file%%.*}.geojson"
done
