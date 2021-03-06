#!/bin/bash -e
source env.sh

REGION=germany
BUILDING_VALUES="=yes =house =residential =apartments =detached =terrace =semidetached_house =static_caravan =bungalow =semi =dormitory =stilt_house =terraced_house =dwelling_house =chalet =summer_cottage =flats =semi-detached =row_house =summer_house =semi_detached =townhouse =houses =hospital =construction =farm =barn =conservatory =cowshed =farm_auxiliary =greenhouse =slurry_tank =stable =sty"

if [ data/$REGION-latest.osm.pbf -nt data/$REGION-latest.o5m ]; then
    echo ">>> Convert OSM dump into O5M format for filtering"
    osmconvert data/$REGION-latest.osm.pbf -o=data/$REGION-latest.o5m
fi
if [ data/$REGION-latest.o5m -nt data/$REGION-filtered.o5m ]; then
    echo ">>> Filter OSM data"
    osmfilter data/$REGION-latest.o5m \
        --keep="building$BUILDING_VALUES" \
        --keep="building:part$BUILDING_VALUES" \
        --keep="disused:building$BUILDING_VALUES" \
        --keep="abandoned:building$BUILDING_VALUES" \
        --keep="demolished:building$BUILDING_VALUES" \
        --keep="removed:building$BUILDING_VALUES" \
        --keep="razed:building$BUILDING_VALUES" \
        --keep="amenity=hospital =nursing_home =prison =school" \
        --keep="(amenity=social_facility and social_facility=nursing_home)" \
        --keep="man_made=bunker_silo =storage_tank =wastewater_plant" \
        --keep="landuse=residential =farmyard" \
        --keep="type=boundary boundary=administrative" \
        -o=data/$REGION-filtered.o5m
fi
echo ">>> Import filtered OSM data into PostGIS database"
osm2pgsql --create --slim --cache $MEMORY --number-processes 8 \
    --flat-nodes data/nodes.bin --style residential_and_buildings.lua \
    --output flex --proj 3035 data/$REGION-filtered.o5m
rm data/nodes.bin
