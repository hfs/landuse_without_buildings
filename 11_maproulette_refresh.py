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
        result = None
        try:
            result = challenge_api.rebuild_challenge(challenge['id'], remove_unmatched=True)
        except maproulette.api.errors.HttpError as err:
            # Apparently this can happen? Rebuilding the tasks will then
            # continue in the background anyway, so we can ignore it and
            # continue.
            if err.status == 504:
                logging.warning("HTTP Error %d when rebuilding challenge %d: %s", err.status, challenge['id'], err.message)
            else:
                raise err
        logging.info("Rebuilt challenge: %s", result)
        time.sleep(30)
        try:
            result = challenge_api.update_challenge(challenge['id'], {'dataOriginDate': osmdump_mtime.isoformat()})
        except maproulette.api.errors.HttpError as err:
            if err.status == 504:
                logging.warning("HTTP Error %d when updating challenge %d: %s", err.status, challenge['id'], err.message)
            else:
                raise err
        logging.info("Updated challenge: %s", result)
        time.sleep(30) # Give it a bit time to rebuild the tasks
