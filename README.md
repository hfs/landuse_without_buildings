# [Maproulette: Residential land use areas without any buildings](https://maproulette.org/browse/projects/41947)

OpenStreetMap maps land use, the primary use of a land area by humans.
Typical uses are residential, commercial, industrial, and so on. See the
[OpenStreetMap wiki on land use](https://wiki.openstreetmap.org/wiki/Key:landuse)
for details.

Some land-use types imply that buildings should be found on that land. A
residential area should have houses.

This project looks at residential and farm yard areas in Germany in
OpenStreetMap which don’t contain any buildings. These are fed as mapping tasks
into [Maproulette](https://maproulette.org/browse/projects/41947), a
micro-tasking platform for OpenStreetMap contributors, where they can improve
the map by adding the buildings and other details, one small task at a time.


## Processing steps

### [01_download.sh](01_download.sh) – Download data

Download a recent
[OpenStreetMap data dump for Germany from Geofabrik](https://download.geofabrik.de/europe/germany.html)
as input data.

### [02_createdb.sh](02_createdb.sh) – Create database

Create the PostGIS database where the data analysis will happen.

### [03_import_osm.sh](03_import_osm.sh) – Import OSM data

Filter the OpenStreetMap data for residential and other relevant land uses and
buildings. OpenStreetMap contains all kinds of geospatial data, e.g. roads,
shops and schools. We are only interested in areas where people live like
residential areas or buildings. The filter is defined in
[residential_and_buildings.lua](residential_and_buildings.lua).

### [04_analyze.sh](04_analyze.sh) – Intersect the data sets

Now filter any land use areas which don't contain or touch any buildings of any
type. These areas should be looked at for sure. There are more residential
areas, where only _some_ of the buildings are mapped. These are harder to
detect. The “empty” land use areas yield already enough tasks to do, so we’ll
use those first.

The data looks like this:

![Map of land use ares and buildings](doc/landuse_buildings.png)

The green and purple areas are land use areas. Light red are buildings. Purple
areas are land use areas which don't contain any buildings and are the ones
that are exported to become challenge tasks.

### [05_export_csv.sh](05_export_csv.sh) – CSV export

This is an export for people who don’t want to use Maproulette, but check one
county or state systematically.

### [06_export_geojson.sh](06_export_geojson.sh) – GeoJSON export

Export the land use polygon as geometry in GeoJSON format that can be uploaded
in Maproulette. Exporting all roughly 25,000 tasks as single file would lead to
one massive, daunting challenge. Instead, they are broken up by state or even
by county, so that each region gets from a few hundred to a few thousand tasks.

Each one of the polygons is presented as mapping task to the Maproulette
contributors. They will use satellite/aerial imagery to see the buildings and
then draw their outlines.

![Maproulette screenshot](doc/maproulette.jpg)

### [07_upload_results.sh](07_upload_results.sh) – Upload output

This is a convenience script for myself to upload updated versions of the
output files as GitHub gist, from where they will be pulled by Maproulette. The
data should be refreshed every few weeks, to account for changes done by other
mappers outside of Maproulette. If the data gets stale, it becomes frustrating
for Maproulette users to get assigned tasks where nothing is left to do.

### [08_maproulette_refresh.py](08_maproulette_refresh.py) – Update Maproulette challenges

Each region gets one challenge in Maproulette. Refresh all challenges after the
data has been updated.


## How to run the analysis yourself

You can run the analysis yourself, e.g. for newer data for a different country
or if you want to modify the criteria.

The processing for Germany requires about 100 GB of temporary disk space and 1
hour of computation time.

### Using Docker and Docker Compose

This is the easier way if you already have [Docker](https://www.docker.com/)
and don’t want to bother with the dependencies.

```
docker-compose up
```

The output files are `data/*.geojson`.

### Running manually

Install PostgreSQL, PostGIS, `osm2pgsql`, `osmconvert` and `osmfilter` (package
`osmctools`) and `npm`.

Install [geojson-rewind](https://github.com/mapbox/geojson-rewind)
using `npm install -g @mapbox/geojson-rewind`.

Edit `env.sh` to set the PostgreSQL credentials.

Run `./run.sh` to execute all processing steps, or call the single scripts to
run specific steps.


## License

The source code of this project is licensed under the terms of the
[MIT license](LICENSE).

As the output data is a Derivative Work of OpenStreetMap data, is has to be
licensed under [ODbL](https://opendatacommons.org/licenses/odbl/). Please refer
to the [OSM Copyright](https://www.openstreetmap.org/copyright/) page and the
information linked there.
