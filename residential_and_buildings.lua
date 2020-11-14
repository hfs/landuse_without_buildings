osm2pgsql.srid = 3035

local tables = {}

tables.landuse = osm2pgsql.define_area_table('landuse', {
    { column = 'geom', type = 'geometry' },
})

tables.building = osm2pgsql.define_area_table('building', {
    { column = 'geom', type = 'geometry' },
})

create_area = { geom = { create = 'area' } }

function osm2pgsql.process_way(object)
    if object.tags.landuse then
        tables.landuse:add_row(create_area)
    end
    if object.tags.building or object.tags['building:part'] then
        tables.building:add_row(create_area)
    end
end

function osm2pgsql.process_relation(object)
    if object.tags.type == 'multipolygon' and object.tags.landuse then
        tables.landuse:add_row(create_area)
    end
    if object.tags.type == 'multipolygon' and
        (object.tags.building or object.tags['building:part'])
    then
        tables.building:add_row(create_area)
    end
end

