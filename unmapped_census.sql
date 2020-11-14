-- Script to intersect the census squares with OSM landuse and building
-- polygons. Delete all census cells which are touched by residential landuse
-- or buildings.

-- First quick pass: Delete census cells whose centroid is contained in
-- landuse polygons. This already eliminates 2/3 of cells.
\echo >>> Add centroid geometry column
ALTER TABLE census_germany ADD COLUMN geom geometry(Point, 3035);
UPDATE census_germany SET geom = ST_SetSRID(st_makepoint(x, y), 3035);
CREATE INDEX ON census_germany USING GIST(geom);

\echo >>> First pass: Delete census cells which are covered by landuse=*
DELETE FROM census_germany c USING landuse l
WHERE ST_Contains(l.geom, c.geom)
;

\echo >>> Add census square geometries, for more precision
ALTER TABLE census_germany DROP COLUMN geom;
ALTER TABLE census_germany ADD COLUMN geom geometry(Polygon, 3035);
-- Census uses center point as ID
UPDATE census_germany SET geom = ST_MakeEnvelope(x - 50, y - 50, x + 50, y + 50, 3035);
CREATE INDEX ON census_germany USING GIST(geom);

\echo >>> Second pass: Intersect squares with landuse polygons
-- Delete another 700000 of 1000000
DELETE FROM census_germany c USING landuse l
WHERE ST_Intersects(l.geom, c.geom)
;

\echo >>> Third pass: Delete all cells intersecting with buildings
DELETE FROM census_germany c USING building b
WHERE ST_Intersects(b.geom, c.geom)
;

\echo >>> Merge clusters of touching census cells into (multi)polygons
-- Cells touching only in corners are ok -- the resulting polygons should be as
-- big as possible
DROP TABLE IF EXISTS census_unmapped;
CREATE TABLE census_unmapped AS
SELECT
    SUM(population) AS population,
    ST_Union(geom) AS geom
FROM
    (
        SELECT
            ST_ClusterDBSCAN(geom, 0, 1) OVER () AS cluster_id,
            *
        FROM
            census_germany
    ) c
GROUP BY
    cluster_id
HAVING
    -- Filter to get the most relevant cases.
    -- We have more than enough cases even with the filter.
    SUM(population) >= 12
    AND ST_Area(ST_Union(geom)) > 100*100
;


\echo >>> Make the clusters look rounder
-- Merge the square cells together to give them a little softer look.
-- Not too much to use only few vertices.
UPDATE census_unmapped
SET geom = ST_Simplify(ST_Buffer(ST_Buffer(geom, 200), -200), 20)
;

CREATE INDEX ON census_unmapped USING GIST(geom);

-- Create a unique ID based on the centroid of the polygon. If the data is
-- regenerated and the polygon is still the same, the ID should remain the
-- same. If the polygon is different, e.g. because parts are now mapped in
-- OSM, the ID should be different.
\echo >>> Generate polygon IDs based on the centroid
ALTER TABLE census_unmapped
ADD COLUMN centroid geometry(Point, 3035);
UPDATE census_unmapped
SET centroid =
    CASE
        WHEN ST_Contains(geom, ST_Centroid(geom))
        THEN ST_Centroid(geom)
        ELSE ST_PointOnSurface(geom)
    END
;

ALTER TABLE census_unmapped
ADD COLUMN id text;
UPDATE census_unmapped
SET id = round(ST_X(centroid)) || ',' || round(ST_Y(centroid))
;
\echo >>> Done
