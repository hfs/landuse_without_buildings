#!/bin/bash -e
set -o pipefail
source env.sh
psql -f subtract_old_challenges.sql -ab -v ON_ERROR_STOP=ON | ts '%Y-%m-%dT%H:%M:%S   '
