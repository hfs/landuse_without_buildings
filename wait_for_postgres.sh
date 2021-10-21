#!/bin/bash -e

source env.sh

echo -n ">>> Waiting for PostgreSQL to become available"
for try in {0..180}; do
    if pg_isready -q -d postgres; then
        echo " -> ok"
        exit 0
    fi
    echo -n .
    sleep 1
done
echo " failed"
exit 1
