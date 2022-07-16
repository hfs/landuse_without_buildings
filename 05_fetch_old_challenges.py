#!/usr/bin/env python3
import json
import logging
import os

import maproulette

try:
    MAPROULETTE_API_KEY = os.environ['MAPROULETTE_API_KEY']
except KeyError:
    raise KeyError(
        "Please set the MapRoulette API key in environment variable MAPROULETTE_API_KEY. "
        "Get it from https://maproulette.org/user/profile")

PROJECT_ID = 41947

logging.basicConfig(format='%(asctime)s %(message)s', level=logging.INFO)

logging.info("Get projects from MapRoulette")
config = maproulette.Configuration(api_key=MAPROULETTE_API_KEY)
project_api = maproulette.Project(config)
challenge_api = maproulette.Challenge(config)

project_challenges = project_api.get_project_challenges(PROJECT_ID, limit=100)['data']
all_challenges = []
for challenge in project_challenges:
    if 23334 <= challenge['id'] <= 23346:
        logging.info("Exporting challenge %d: %s", challenge['id'], challenge['name'])
        # Need both CSV and GeoJSON: The CSV has the mapper name, and the GeoJSON has the geometry
        challenge_status_csv = challenge_api.extract_task_summaries(challenge['id'], limit=10_000, page=0,
                                                                    status="0,1,2,3,4,5,6,9")
        with open(f"data/challenge_{challenge['id']}_tasks.csv", 'w') as outfile:
            outfile.write(challenge_status_csv['data'])
        challenge_status_geojson = challenge_api.get_challenge_geojson(challenge['id'])
        with open(f"data/challenge_{challenge['id']}_tasks.geojson", 'w') as outfile:
            json.dump(challenge_status_geojson['data'], outfile)
logging.info("Done")
