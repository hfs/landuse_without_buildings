#!/usr/bin/env python3
import datetime
import logging
import os
import pathlib
import time

import maproulette

try:
    MAPROULETTE_API_KEY = os.environ['MAPROULETTE_API_KEY']
except KeyError:
    raise KeyError(
        "Please set the MapRoulette API key in environment variable MAPROULETTE_API_KEY. "
        "Get it from https://maproulette.org/user/profile")
PROJECT_ID = 41947

logging.basicConfig(format='%(asctime)s %(message)s', level=logging.INFO)

osmdump = pathlib.Path('data/germany-latest.osm.pbf')
osmdump_mtime = datetime.datetime.fromtimestamp(osmdump.stat().st_mtime)

config = maproulette.Configuration(api_key=MAPROULETTE_API_KEY)
project_api = maproulette.Project(config)
challenge_api = maproulette.Challenge(config)

project_challenges = project_api.get_project_challenges(PROJECT_ID, limit=100)['data']
for challenge in project_challenges:
    if challenge['enabled'] and challenge['status'] == 3:
        logging.info("Rebuilding challenge %d", challenge['id'])
        # This also rebuilds the tasks
        result = challenge_api.update_challenge(challenge['id'], {'dataOriginDate': osmdump_mtime.isoformat()})
        logging.info("Result: %s", result)
        time.sleep(10) # Give it a bit time to rebuild the tasks
