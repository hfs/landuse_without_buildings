local tables = {}

tables.landuse = osm2pgsql.define_area_table('landuse', {
    { column = 'landuse', type = 'text' },
    { column = 'geom', type = 'geometry' },
})

tables.building = osm2pgsql.define_area_table('building', {
    { column = 'building', type = 'text' },
    { column = 'geom', type = 'geometry' },
})

tables.administrative = osm2pgsql.define_area_table('administrative', {
    { column = 'name', type = 'text' },
    { column = 'admin_level', type = 'text' },
    { column = 'geom', type = 'geometry' },
})

tables.highway = osm2pgsql.define_way_table('highway', {
    { column = 'highway', type = 'text' },
    { column = 'geom', type = 'linestring' },
})

tables.unwanted = osm2pgsql.define_area_table('unwanted', {
    { column = 'kind', type = 'text' },
    { column = 'geom', type = 'geometry' },
})

function building_type(object)
    building_value = object.tags.building or object.tags['building:part'] or
        object.tags['abandoned:building'] or object.tags['demolished:building'] or
        object.tags['removed:building'] or object.tags['razed:building']
    if object.tags.man_made then
        man_made = object.tags.man_made
        if man_made == 'bunker_silo' or man_made == 'storage_tank' or
                man_made == 'wastewater_plant' then
            building_value = man_made
        end
    end
    return building_value
end

function osm2pgsql.process_way(object)
    if object.tags.landuse then
        row = { geom = { create = 'area' }, landuse = object.tags.landuse }
        tables.landuse:add_row(row)
    end
    building_value = building_type(object)
    if building_value then
        row = { geom = { create = 'area' }, building = building_value }
        tables.building:add_row(row)
    end
    if object.tags.highway then
        tables.highway:add_row{ highway = object.tags.highway }
    end
    if object.tags.leisure or object.tags.amenity or object.tags.water then
        kind = object.tags.leisure or object.tags.amenity or object.tags.water
        row = { geom = { create = 'area' }, kind = kind }
        tables.unwanted:add_row(row)
    end
end

function osm2pgsql.process_relation(object)
    if object.tags.type == 'multipolygon' and object.tags.landuse then
        row = { geom = { create = 'area' }, landuse = object.tags.landuse }
        tables.landuse:add_row(row)
    end
    building_value = building_type(object)
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
    if object.tags.type == 'multipolygon' and (object.tags.leisure or object.tags.amenity or object.tags.water) then
        kind = object.tags.leisure or object.tags.amenity or object.tags.water
        row = { geom = { create = 'area' }, kind = kind }
        tables.unwanted:add_row(row)
    end
end

