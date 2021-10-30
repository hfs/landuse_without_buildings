\echo >>> Calculate area of landuse

ALTER TABLE landuse DROP COLUMN IF EXISTS area;
ALTER TABLE landuse ADD COLUMN area float;
UPDATE landuse SET area = ST_Area(geom);

\echo >>> Calculate area of buildings

-- This takes way too long when using geography, so instead use LAEA
-- pseudo-meters. Should be good enough when only looking at the ratio of
-- pseudo-squaremeters to pseudo-squaremeters on a local scale.
-- UPDATE and adding a column will rewrite the table anyway. It's faster to
-- create a new table.
BEGIN;
    ALTER TABLE building DROP COLUMN IF EXISTS area;
    CREATE TABLE building_area AS
        SELECT *, ST_Area(geom) AS area FROM building;
    ALTER TABLE building_area ADD PRIMARY KEY (area_id);
    CREATE INDEX ON building_area USING GIST(geom);
    DROP TABLE building;
    ALTER TABLE building_area RENAME TO building;
COMMIT;

\echo >>> Filter landuse with "too few" buildings

DROP TABLE IF EXISTS landuse_with_few_buildings;
CREATE TABLE landuse_with_few_buildings AS
    WITH germany AS (
        SELECT geom
        FROM administrative
        WHERE
            admin_level = '2' AND
            name = 'Deutschland'
    )
    SELECT
        l.area_id,
        l.landuse,
        l.area,
        SUM(b.area) / l.area AS building_fraction,
        l.geom
    FROM
        germany g,
        landuse l
        CROSS JOIN LATERAL (
            SELECT * FROM building b WHERE ST_Intersects(l.geom, b.geom)
        ) b
    WHERE
        l.landuse = 'residential' AND
        l.area > 25000 AND
        ST_Within(l.geom, g.geom)
    GROUP BY l.area_id, l.landuse, l.area, l.geom
    HAVING SUM(b.area) / l.area < 0.05
;
CREATE INDEX ON landuse_with_few_buildings USING GIST(geom);

\echo >>> Split landuse areas by highways

DROP TABLE IF EXISTS landuse_split CASCADE;
CREATE TABLE landuse_split AS
WITH split AS (
    SELECT
      l.area_id,
      CASE
        WHEN l.area_id >= 0 THEN 'https://osm.org/way/' || l.area_id
        ELSE 'https://osm.org/relation/' || -l.area_id
      END AS osm_id,
      (ST_Dump(ST_Split(l.geom, ST_Collect(h.geom)))).geom,
      ST_Centroid(l.geom) AS centroid
    FROM
      landuse_with_few_buildings l
      CROSS JOIN LATERAL (
        SELECT * FROM highway h WHERE ST_Intersects(l.geom, h.geom)
      ) h
    GROUP BY l.area_id, l.geom
)
SELECT
    ROW_NUMBER() OVER (ORDER BY s.area_id, ST_Azimuth(s.centroid, ST_Centroid(s.geom))) - 1 AS id,
    s.osm_id,
    s.geom
FROM split s
;
CREATE INDEX ON landuse_split(osm_id);
CREATE INDEX ON landuse_split USING GIST(geom);

\echo >>> Join sliver polygons (very narrow polygons with small area) with their neighbor

-- Step 1: For each sliver polygon (defined by ST_MaximumInscribedCircle) find
-- the non-sliver neighbor with the longest shared border
--
-- This is created as materialized view, because it has to be executed in a loop
-- and is easy to repeat by refreshing.
DROP MATERIALIZED VIEW IF EXISTS sliver_neighbor;
CREATE MATERIALIZED VIEW sliver_neighbor AS
SELECT
    id_small_poly,
    id_large_poly
FROM
    (
        SELECT
            a.id AS id_small_poly,
            b.id AS id_large_poly,
            -- ST_Intersection is guaranteed to be a (multi)linestring because
            -- we check for (only) overlapping borders in ST_Relate
            RANK() OVER (
                PARTITION BY a.id
                ORDER BY ST_Length(ST_Intersection(a.geom, b.geom)) DESC
            ) AS neighbor_rank
        FROM landuse_split a
        CROSS JOIN LATERAL (
            SELECT *
            FROM landuse_split b
            WHERE
                -- coming from the same source OSM area
                a.osm_id = b.osm_id AND
                -- Shared boundary line
                ST_Relate(a.geom, b.geom, 'FF2F1*212') AND
                -- Requires PostGIS >= 3.1
                (ST_MaximumInscribedCircle(b.geom)).radius >= 20) b
        WHERE
            (ST_MaximumInscribedCircle(a.geom)).radius < 20
     ) all_neighbors
WHERE
    neighbor_rank = 1;

-- Need to run the sliver detection and removal recursively, because there are
-- slivers that are only surrounded by slivers and not found in the first
-- iteration
DO $$
DECLARE
    number_of_slivers integer := 0;
BEGIN
    number_of_slivers := COUNT(*) FROM sliver_neighbor;
    WHILE number_of_slivers > 0 LOOP
        RAISE NOTICE 'Number of slivers: %', number_of_slivers;

        -- Step 2: Merge "large" polygons with neighbor slivers
        UPDATE landuse_split l
        SET geom = merged.geom
        FROM (
            SELECT l2.id, ST_Union(l2.geom, ST_Union(s.geom)) AS geom
            FROM landuse_split l2, landuse_split s, sliver_neighbor n
            WHERE l2.id = n.id_large_poly AND s.id = n.id_small_poly
            GROUP BY l2.id, l2.geom
        ) merged
        WHERE l.id = merged.id
        ;

        -- Step 3: Remove slivers
        DELETE FROM landuse_split l
        USING sliver_neighbor n
        WHERE l.id = n.id_small_poly
        ;

        REFRESH MATERIALIZED VIEW sliver_neighbor;
        number_of_slivers := COUNT(*) FROM sliver_neighbor;
    END LOOP;
END$$;

\echo >>> Regenerate IDs after removals

ALTER TABLE landuse_split ADD COLUMN new_id text;
UPDATE landuse_split l
SET new_id = l.osm_id || '//' || rank_in_group
FROM (
    SELECT l2.id,
    row_number() OVER (PARTITION BY l2.osm_id ORDER BY l2.osm_id, l2.id) AS rank_in_group
    FROM landuse_split l2
) renumber
WHERE l.id = renumber.id
;
ALTER TABLE landuse_split DROP COLUMN id CASCADE;
ALTER TABLE landuse_split RENAME COLUMN new_id TO id;
ALTER TABLE landuse_split ADD PRIMARY KEY(id);

\echo >>> Re-intersect with buildings after merging to get the area fraction

ALTER TABLE landuse_split ADD COLUMN area float;
UPDATE landuse_split SET area = ST_Area(geom);
ALTER TABLE landuse_split ADD COLUMN building_fraction float;
UPDATE landuse_split l
SET building_fraction = f.building_fraction
FROM (
    SELECT
        l2.id,
        SUM(b.area) / l2.area AS building_fraction
    FROM
        landuse_split l2
        CROSS JOIN LATERAL (
            SELECT * FROM building b WHERE ST_Intersects(l2.geom, b.geom)
        ) b
    GROUP BY l2.id
) f
WHERE l.id = f.id
;
UPDATE landuse_split SET building_fraction = 0 WHERE building_fraction IS NULL;

\echo >>> Number of landuse areas by building fraction:

SELECT
    COUNT(*) FILTER (WHERE building_fraction = 0) AS "building_fraction = 0",
    COUNT(*) FILTER (
        WHERE building_fraction > 0 AND
        building_fraction <= 0.05
    ) AS "0 < building_fraction ≤ 5 %",
    COUNT(*) FILTER (WHERE building_fraction > 0.05) AS "building_fraction > 5 %"
FROM landuse_split
;

\echo >>> Median size of landuse areas with building fraction = 0:

SELECT percentile_cont(0.5) WITHIN GROUP(ORDER BY area) AS median
FROM landuse_split
WHERE building_fraction = 0
;

