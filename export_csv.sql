\COPY (SELECT id, osm_id, area, building_fraction FROM landuse_split WHERE building_fraction < 0.04 AND area >= 500 ORDER BY id) TO STDOUT (FORMAT csv, HEADER)
