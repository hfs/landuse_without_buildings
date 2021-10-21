SELECT json_build_object(
    'type', 'FeatureCollection',
    'features', json_agg(ST_AsGeoJSON(u.*)::json)
)
FROM (
	SELECT
		id,
		osm_id,
		area,
		building_fraction,
		-- No idea why ForceRHR doesn't help
		ST_ForceRHR(ST_Transform(geom, 4326)) AS geom
	FROM landuse_split
	WHERE building_fraction < 0.05
	ORDER BY id
) u
;
