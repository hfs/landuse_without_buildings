\echo >>> Filter old tasks and apply negative buffer

DROP TABLE IF EXISTS old_tasks_filtered;
CREATE TABLE old_tasks_filtered AS
SELECT
    id,
    osm_id,
    mr_taskid,
    mr_taskstatus,
    -- Negative buffer to avoid intersection at the edges and to allow for
    -- slight changes to the geometry.
    ST_Buffer(ST_Transform(geom, 3035), -10) AS geom
FROM old_tasks
WHERE
    mr_taskstatus NOT IN ('Created', 'Skipped', 'Too_Hard')
;

\echo >>> Remove tasks that were already dealt with

DELETE FROM landuse_split l
USING old_tasks_filtered o
WHERE ST_Intersects(l.geom, o.geom)
;