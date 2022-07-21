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
        building_fraction <= 0.04 AND
	area >= 500
    ORDER BY id
) u
;

