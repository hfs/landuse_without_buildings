\COPY (SELECT id, osm_id, state, area, building_fraction FROM landuse_split WHERE building_fraction < 0.05 ORDER BY state, id) TO STDOUT (FORMAT csv, HEADER)
