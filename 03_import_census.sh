#!/bin/bash -e
source env.sh

echo ">>> Filter raw census data for inhabited cells"
sed -e '/;-1\r$/d; s/[^;]*;//' data/Zensus_Bevoelkerung_100m-Gitter.csv > data/Zensus_Bevoelkerung_100m-Gitter_filtered.csv

echo ">>> Import Census into PostgreSQL database '$PGDATABASE'"
psql -v ON_ERROR_STOP=1 --single-transaction <<EOF
DROP TABLE IF EXISTS census_germany;
CREATE TABLE census_germany (
    x int8,
    y int8,
    population int8
);
\COPY census_germany FROM data/Zensus_Bevoelkerung_100m-Gitter_filtered.csv (FORMAT CSV, DELIMITER ';', NULL '', HEADER)

EOF
