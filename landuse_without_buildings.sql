DROP TABLE IF EXISTS landuse_without_buildings;
CREATE TABLE landuse_without_buildings AS
SELECT l.*
FROM landuse l LEFT JOIN building b
ON ST_Intersects(l.geom, b.geom)
WHERE b.area_id IS NULL
AND l.area > 5000
;
CREATE INDEX ON landuse_without_buildings USING GIST(geom);

ALTER TABLE landuse ADD COLUMN area float;
UPDATE landuse SET area = ST_Area(ST_Transform(geom, 4326)::geography, true) ;
CREATE INDEX ON landuse(area);

DROP TABLE IF EXISTS county_or_district;
CREATE TABLE county_or_district AS
SELECT county.*, state.name AS state
FROM
  administrative state,
  (SELECT * FROM administrative WHERE admin_level = '6') county
WHERE
  ST_Within(county.geom, state.geom) AND
  state.admin_level = '4' AND
  state.name NOT IN ('Berlin', 'Hamburg', 'Bremen')
UNION
SELECT district.*, state.name AS state
FROM
  administrative state,
  (SELECT * FROM administrative WHERE admin_level = '9') district
WHERE
  ST_Within(district.geom, state.geom) AND
  state.admin_level = '4' AND 
  state.name IN ('Berlin', 'Hamburg', 'Bremen')
;
CREATE INDEX ON county_or_district USING GIST(geom);

DROP TABLE IF EXISTS landuse_export;
CREATE TABLE landuse_export AS
SELECT DISTINCT ON (landuse.area_id)
  county.state,
  county.name AS county,
  landuse.*
FROM
  landuse_without_buildings landuse,
  county_or_district county
WHERE
  ST_Intersects(landuse.geom, county.geom)
ORDER BY landuse.area_id, ST_Area(ST_Intersection(landuse.geom, county.geom)) DESC
;
CREATE INDEX ON landuse_export USING GIST(geom);

