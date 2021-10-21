osm2pgsql.srid = 3035

local tables = {}

tables.landuse = osm2pgsql.define_area_table('landuse', {
    { column = 'landuse', type = 'text' },
    { column = 'geom', type = 'geometry', projection=3035 },
})

tables.building = osm2pgsql.define_area_table('building', {
    { column = 'building', type = 'text' },
    { column = 'geom', type = 'geometry', projection=3035 },
})

tables.administrative = osm2pgsql.define_area_table('administrative', {
    { column = 'name', type = 'text' },
    { column = 'admin_level', type = 'text' },
    { column = 'geom', type = 'geometry', projection=3035 },
})

tables.highway = osm2pgsql.define_way_table('highway', {
    { column = 'highway', type = 'text' },
    { column = 'geom', type = 'linestring', projection=3035 },
})

function osm2pgsql.process_way(object)
    if object.tags.landuse then
        row = { geom = { create = 'area' }, landuse = object.tags.landuse }
        tables.landuse:add_row(row)
    end
    building_value = object.tags.building or object.tags['building:part'] or
        object.tags['abandoned:building'] or object.tags['demolished:building'] or
        object.tags['removed:building'] or object.tags['razed:building']
    if building_value then
        row = { geom = { create = 'area' }, building = building_value }
        tables.building:add_row(row)
    end
    if object.tags.highway then
        tables.highway:add_row{ highway = object.tags.highway }
    end
end

function osm2pgsql.process_relation(object)
    if object.tags.type == 'multipolygon' and object.tags.landuse then
        row = { geom = { create = 'area' }, landuse = object.tags.landuse }
        tables.landuse:add_row(row)
    end
    building_value = object.tags.building or object.tags['building:part'] or
        object.tags['abandoned:building'] or object.tags['demolished:building'] or
        object.tags['removed:building'] or object.tags['razed:building']
    if object.tags.type == 'multipolygon' and building_value then
        row = { geom = { create = 'area' }, building = building_value }
        tables.building:add_row(row)
    end
    if object.tags.type == 'boundary' and object.tags.boundary == 'administrative' then
        row = {
            geom = { create = 'area' },
            name = object.tags.name,
            admin_level = object.tags.admin_level
        }
        tables.administrative:add_row(row)
    end
end

