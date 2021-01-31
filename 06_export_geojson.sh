#!/bin/bash -e
source env.sh
echo ">>> Export results as one GeoJSON file per region (state/county)"

export_geojson() {
	cat <<-EOF
		SELECT json_build_object(
			'type', 'FeatureCollection',
			'features', json_agg(ST_AsGeoJSON(u.*)::json)
		)
		FROM (
			SELECT
				'https://osm.org/' ||
				CASE WHEN area_id < 0
					THEN 'relation/' || (-area_id)::text
					ELSE 'way/' || area_id::text
				END || '/' AS id,
				ROUND(area) AS area,
				-- No idea why ForceRHR doesn't help
				ST_ForceRHR(ST_Transform(geom, 4326)) AS geom
			FROM landuse_export
			WHERE $@
			ORDER BY area_id
		) u
		;
	EOF
}

sql() {
	psql -t -v ON_ERROR_STOP=ON "$@"
}

export_geojson "state IN ('Berlin', 'Bremen', 'Hamburg', 'Saarland')" | sql > data/Berlin+Bremen+Hamburg+Saarland.geojson

for state in Baden-Württemberg Bayern Brandenburg Hessen Mecklenburg-Vorpommern Nordrhein-Westfalen Rheinland-Pfalz Sachsen Sachsen-Anhalt Schleswig-Holstein Thüringen
do
	export_geojson "state = '$state'" | sql > data/$state.geojson
done

# Special handling of Niedersachsen: Export counties with many cases as single
# files. Collect all the rest as one "Niedersachsen" file.
for county in "Landkreis Ammerland" "Landkreis Aurich" "Landkreis Cloppenburg" "Landkreis Cuxhaven" "Landkreis Diepholz" "Landkreis Emsland" "Landkreis Friesland" "Landkreis Grafschaft Bentheim" "Landkreis Leer" "Landkreis Oldenburg" "Landkreis Osnabrück" "Landkreis Rotenburg (Wümme)" "Landkreis Vechta" "Landkreis Wittmund" "Stade"
do
	export_geojson "state = 'Niedersachsen' AND county = '$county'" | sql > "data/$county.geojson"
done

export_geojson "state = 'Niedersachsen' AND county NOT IN (
	'Landkreis Ammerland',
	'Landkreis Aurich',
	'Landkreis Cloppenburg',
	'Landkreis Cuxhaven',
	'Landkreis Diepholz',
	'Landkreis Emsland',
	'Landkreis Friesland',
	'Landkreis Grafschaft Bentheim',
	'Landkreis Leer',
	'Landkreis Oldenburg',
	'Landkreis Osnabrück',
	'Landkreis Rotenburg (Wümme)',
	'Landkreis Vechta',
	'Landkreis Wittmund',
	'Stade'
	)" | sql > data/Niedersachsen.geojson

# For some reason, the exported GeoJSON files do not follow the "right-hand
# rule" how to order the polygon nodes. Fix them using 'geojson-rewind'.
for file in data/*.geojson; do
	mv "$file" "$file.left"
	geojson-rewind "$file.left" > "$file"
	rm "$file.left"
done

