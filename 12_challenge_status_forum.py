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

config = maproulette.Configuration(api_key=MAPROULETTE_API_KEY)
project_api = maproulette.Project(config)

query_params = {
    'includeByPriority': 'false',
    'onlyEnabled': 'true',
    'projectList': PROJECT_ID
}
project_challenges = project_api.get_project_challenges(PROJECT_ID, limit=100)['data']
project_challenges = {c['id']: c for c in project_challenges}
summary = project_api.get(endpoint='/data/project/summary', params=query_params)['data']
summary = [p for p in summary
        if p['id'] in project_challenges and
            project_challenges[p['id']]['enabled'] and
            not project_challenges[p['id']]['isArchived']]
summary = reversed(sorted(summary, key=lambda p: p['actions']['available']))
print('[list]')
for project in summary:
    print(f'[*] [url={project_api.base_url}/browse/challenges/{project["id"]}]'
            f'{project["name"]}[/url]: '
            f'{project["actions"]["available"]} / {project["actions"]["total"]} [/*]')
print('[/list]')
