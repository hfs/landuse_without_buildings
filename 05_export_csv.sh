#!/bin/bash -e
source env.sh
echo ">>> Export results as one CSV table per state"
for state in Baden-Württemberg Bayern Berlin Brandenburg Bremen Hamburg Hessen Mecklenburg-Vorpommern Niedersachsen Nordrhein-Westfalen Rheinland-Pfalz Saarland Sachsen Sachsen-Anhalt Schleswig-Holstein Thüringen
do
    echo "Landkreis/kreisfreie Stadt/Stadtbezirk,URL,Fläche" > data/$state.csv
    psql -t -c "\COPY (SELECT county, 'https://www.openstreetmap.org/' || (CASE WHEN area_id < 0 THEN 'relation/' || (-area_id)::text ELSE 'way/' || area_id::text END) || '/' AS url, ROUND(area)::int AS area FROM landuse_export WHERE state = '$state' ORDER BY county, area DESC) TO STDOUT (FORMAT csv)" >> data/$state.csv
done
