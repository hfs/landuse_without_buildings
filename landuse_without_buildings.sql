\echo >>> Keep only residential landuse

-- TODO May need to subtract parks, forests, etc from residential

DELETE FROM landuse WHERE landuse != 'residential';

\echo >>> Reproject landuse and calculate area

-- This takes way too long when using geography, so instead use LAEA
-- pseudo-meters. Should be good enough when only looking at the ratio of
-- pseudo-squaremeters to pseudo-squaremeters on a local scale.
-- UPDATE and adding a column will rewrite the table anyway. It's faster to
-- create a new table.
BEGIN;
    CREATE TABLE landuse_area AS
        SELECT area_id, landuse, ST_Area(ST_Transform(geom, 3035)) AS area,
        ST_Transform(geom, 3035) AS geom FROM landuse;
    ALTER TABLE landuse_area ADD PRIMARY KEY (area_id);
    CREATE INDEX ON landuse_area USING GIST(geom);
    DROP TABLE landuse;
    ALTER TABLE landuse_area RENAME TO landuse;
COMMIT;

\echo >>> Reproject buildings and calculate area

BEGIN;
    CREATE TABLE building_area AS
        SELECT area_id, building, ST_Area(ST_Transform(geom, 3035)) AS area,
        ST_Transform(geom, 3035) AS geom FROM building;
    ALTER TABLE building_area ADD PRIMARY KEY (area_id);
    CREATE INDEX ON building_area USING GIST(geom);
    DROP TABLE building;
    ALTER TABLE building_area RENAME TO building;
COMMIT;

\echo >>> Reproject highways

BEGIN;
    CREATE TABLE highway_reprojected AS
      SELECT way_id, highway, ST_Transform(geom, 3035) AS geom FROM highway;
    ALTER TABLE highway_reprojected ADD PRIMARY KEY (way_id);
    CREATE INDEX ON highway_reprojected USING GIST(geom);
    DROP TABLE highway;
    ALTER TABLE highway_reprojected RENAME TO highway;
COMMIT;

\echo >>> Filter landuse from previous projects

-- Any polygon that has already been looked at in previous projects should not
-- be presented to MapRoulette users again.

DROP TABLE IF EXISTS blacklist;
CREATE TABLE blacklist (id text);
\COPY blacklist FROM 'landuse_blacklist.csv' (FORMAT CSV, HEADER)
ALTER TABLE blacklist ADD COLUMN area_id bigint;
UPDATE blacklist SET area_id =
  CASE
    WHEN id LIKE '%/way/%'
      THEN CAST(regexp_replace(id, '.*/', '') AS bigint)
    WHEN id LIKE '%/relation/%'
      THEN - CAST(regexp_replace(id, '.*/', '') AS bigint)
  END
;
DELETE FROM landuse l
USING blacklist b
WHERE l.area_id = b.area_id
;

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
      landuse l
      CROSS JOIN LATERAL (
        SELECT * FROM highway h WHERE ST_Intersects(l.geom, h.geom)
      ) h
    WHERE l.area >= 25000
    GROUP BY l.area_id, l.geom
    UNION ALL
    SELECT
        l.area_id,
        CASE
            WHEN l.area_id >= 0 THEN 'https://osm.org/way/' || l.area_id
            ELSE 'https://osm.org/relation/' || -l.area_id
        END AS osm_id,
        l.geom,
        ST_Centroid(l.geom) AS centroid
    FROM
        landuse l
        LEFT JOIN highway h ON ST_Intersects(l.geom, h.geom)
    WHERE
        l.area >= 25000 AND
        h.geom IS NULL
)
SELECT
    ROW_NUMBER() OVER (ORDER BY s.area_id, ST_Azimuth(s.centroid, ST_Centroid(s.geom))) - 1 AS id,
    s.osm_id,
    s.geom
FROM split s
;
ALTER TABLE landuse_split ADD PRIMARY KEY (id);
CREATE INDEX ON landuse_split(osm_id);
CREATE INDEX ON landuse_split USING GIST(geom);
VACUUM ANALYZE landuse_split;

\echo >>> Join sliver polygons (very narrow polygons with small area) with their neighbor

-- Step 1: For each sliver polygon (defined by ST_MaximumInscribedCircle) find
-- the non-sliver neighbor with the longest shared border
DROP TABLE IF EXISTS sliver_neighbor;
CREATE TABLE sliver_neighbor AS
SELECT
    id_small_poly,
    id_neighbor
FROM
    (
        SELECT
            a.id AS id_small_poly,
            b.id AS id_neighbor,
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
                ST_Relate(a.geom, b.geom, 'FF2F1*212')
        ) b
        WHERE
            -- Requires PostGIS >= 3.1
            (ST_MaximumInscribedCircle(a.geom)).radius < 20
     ) all_neighbors
WHERE
    neighbor_rank = 1;

-- Now we want to merge slivers with their "largest" neighbor. We need to
-- identify the transitive closures first, because there may be chains of
-- neighbors sliver -> sliver -> regular, or circles sliver <-> sliver.
DROP TABLE IF EXISTS transitive_group;
-- Label every polygon with the ID of their transitive group.
-- Label 0 = Not yet touched in the algorithm
CREATE TABLE transitive_group (
    id INTEGER PRIMARY KEY,
    label INTEGER NOT NULL DEFAULT 0
);
DO $funcBody$
    DECLARE
        label1 integer;
        label2 integer;
        nextlabel integer;
        pair sliver_neighbor%rowtype;
    BEGIN
        DELETE FROM transitive_group;
        INSERT INTO transitive_group(id)
            SELECT DISTINCT unnest(array[id_small_poly, id_neighbor])
            FROM sliver_neighbor ORDER BY 1;
        nextlabel := 0;
        FOR pair IN SELECT * FROM sliver_neighbor
        LOOP
            SELECT label INTO label1 FROM transitive_group WHERE id = pair.id_small_poly;
            SELECT label INTO label2 FROM transitive_group WHERE id = pair.id_neighbor;
            IF label1 = 0 AND label2 = 0 THEN
                -- Both not yet seen: Start a new group
                nextlabel := nextlabel+1;
                UPDATE transitive_group SET label = nextlabel WHERE id in (pair.id_small_poly, pair.id_neighbor);
            ELSIF label1 = 0 AND label2 != 0 THEN
                -- One of them seen: Assign the same label to the other one
                UPDATE transitive_group SET label = label2 WHERE id = pair.id_small_poly;
            ELSIF label1 != 0 AND label2 = 0 THEN
                -- One of them seen: Assign the same label to the other one
                UPDATE transitive_group SET label = label1 WHERE id = pair.id_neighbor;
            ELSIF label1 != label2 THEN
                -- Found the connection between two groups: Merge them
                UPDATE transitive_group SET label = label1 WHERE label = label2;
            END IF;
        END LOOP;
    END;
$funcBody$ LANGUAGE plpgsql;

CREATE INDEX ON transitive_group(label);

DROP TABLE IF EXISTS max_per_group;
CREATE TABLE max_per_group AS
SELECT max(id) AS max_id, label
FROM transitive_group t
GROUP BY LABEL
;
ALTER TABLE max_per_group ADD PRIMARY KEY (label);
CREATE INDEX ON max_per_group(max_id);

-- Now merge all polygons that are in the same group. Use the polygon with the
-- largest ID (it's not important which one out of the group) and overwrite its
-- geometry with the union of the group. Delete all other polygons in the group.
UPDATE landuse_split l
SET geom = merged.geom
FROM
    max_per_group m
    CROSS JOIN LATERAL
    (
        SELECT m.max_id AS id, ST_Union(s.geom) AS geom
        FROM landuse_split s, transitive_group t
        WHERE
            m.label = t.label AND
            t.id = s.id
        GROUP BY m.max_id
    ) merged
WHERE
    l.id = m.max_id
;

DELETE FROM landuse_split l
USING
    max_per_group m,
    transitive_group t
WHERE
    l.id = t.id AND
    t.label = m.label AND
    l.id != m.max_id
;

\echo >>> Calculate area of polygons

ALTER TABLE landuse_split ADD COLUMN area float;
UPDATE landuse_split SET area = ST_Area(geom);

\echo >>> Cut up too large polygons

-- Add sequence to generate new, unique IDs when inserting split polygons
CREATE SEQUENCE landuse_split_id_seq
OWNED BY landuse_split.id
;
SELECT setval('landuse_split_id_seq', (SELECT MAX(id) FROM landuse_split));

CREATE OR REPLACE FUNCTION split_polygon_in_half(
    geom geometry
)
RETURNS geometry(Geometrycollection)
AS $funcBody$
DECLARE
    bbox geometry(Linestring);
    blade geometry(Linestring);
    blade_elongated geometry(Linestring);
    elongation_factor double precision := 1.5;
BEGIN
    SELECT ST_Boundary(ST_OrientedEnvelope(geom)) INTO bbox;
    SELECT
        ST_OffsetCurve(
            ST_MakeLine( -- short edge
                ST_PointN(bbox, 1),
                ST_PointN(bbox, 2)
            ),
            ST_Distance(
                -- long edge
                ST_PointN(bbox, 2),
                ST_PointN(bbox, 3)
            ) / 2
        )
        INTO blade;
    -- Need to extend the cut line in case it ends exactly on the polygon
    -- boundary. In that case no cut would be performed.
    SELECT
        ST_Affine(blade,
            elongation_factor, 0,
            0, elongation_factor,
            (elongation_factor - 1) * -ST_X(ST_LineInterpolatePoint(blade, 0.5)),
            (elongation_factor - 1) * -ST_Y(ST_LineInterpolatePoint(blade, 0.5))
        )
        INTO blade_elongated;
    RETURN ST_Split(geom, blade_elongated);
END
$funcBody$
LANGUAGE plpgsql
;

CREATE OR REPLACE FUNCTION split_too_large_polygons()
RETURNS void
AS $funcBody$
BEGIN
    DROP TABLE IF EXISTS landuse_too_big;
    CREATE TABLE landuse_too_big AS
    SELECT
        osm_id,
        id AS original_id,
        -- new_id doesn't have to be unique. It's only used to get a
        -- reproducable order when regenerating the IDs in the next step.
        id + (dump).path[1] AS new_id,
        (dump).geom
    FROM (
        SELECT
            osm_id,
            id,
            geom,
            ST_Dump(split_polygon_in_half(geom)) AS dump
        FROM landuse_split
        WHERE area > 100000
    ) polygon_halves
    ;
    DELETE FROM landuse_split s
    USING landuse_too_big b
    WHERE
        s.id = b.original_id
    ;
    INSERT INTO landuse_split(osm_id, geom, id, area)
    SELECT
        osm_id,
        geom,
        nextval('landuse_split_id_seq') AS id,
        ST_Area(geom) AS area
    FROM landuse_too_big
    ORDER BY osm_id, new_id
    ;
END;
$funcBody$
LANGUAGE plpgsql
;

-- Split too big polygons recursively, until none remain
DO $loopBody$
DECLARE
    polygon_count integer;
BEGIN
    SELECT COUNT(*) INTO polygon_count FROM landuse_split WHERE area >= 100000;
    WHILE polygon_count > 0
    LOOP
        RAISE NOTICE '>>> Polygons to split: %', polygon_count;
        PERFORM split_too_large_polygons();
        SELECT COUNT(*) INTO polygon_count FROM landuse_split WHERE area >= 100000;
    END LOOP;
END;
$loopBody$ LANGUAGE plpgsql
;

SELECT COUNT(*)  FROM landuse_split WHERE area >= 100000;

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

\echo >>> Intersect with buildings to get the area fraction

ALTER TABLE landuse_split ADD COLUMN building_fraction float;
UPDATE landuse_split l
SET building_fraction = f.building_fraction
FROM (
    SELECT
        l2.id,
        SUM(b.area) / l2.area AS building_fraction
    FROM
        landuse_split l2,
        building b
    WHERE ST_Intersects(l2.geom, b.geom)
    GROUP BY l2.id
) f
WHERE l.id = f.id
;
UPDATE landuse_split SET building_fraction = 0 WHERE building_fraction IS NULL;

\echo >>> Number of landuse areas by area and building fraction:

SELECT
    CASE
        WHEN area_rounded >= 100000 THEN '≥ 100,000'
        ELSE to_char(area_rounded, '999,999')
    END AS "area [m²]",
    CASE
        WHEN building_fraction_rounded >= 0.1 THEN '≥ 10 %'
        ELSE ROUND(building_fraction_rounded * 100) || ' %'
    END AS building_fraction,
    COUNT(*)
FROM (
    SELECT
        CASE
            WHEN area > 100000 THEN 100000
            ELSE floor(area / 5000) * 5000
        END AS area_rounded,
        CASE
            WHEN building_fraction > 0.1 THEN 0.1
            ELSE floor(building_fraction / 0.01) * 0.01
        END AS building_fraction_rounded
    FROM
        landuse_split ls
) rounded
GROUP BY area_rounded, building_fraction_rounded
ORDER BY area_rounded, building_fraction_rounded
\crosstabview
;

\echo >>> Median size of landuse areas with building fraction = 0:

SELECT percentile_cont(0.5) WITHIN GROUP(ORDER BY area) AS median
FROM landuse_split
WHERE building_fraction = 0
;
