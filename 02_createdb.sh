#!/bin/bash -e
source env.sh

# First PostgreSQL startup takes a bit longer
./wait_for_postgres.sh
echo ">>> Create database '$PGDATABASE'"
createdb $PGDATABASE
psql -c "CREATE EXTENSION postgis"
