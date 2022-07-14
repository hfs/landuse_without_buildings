FROM debian:testing
LABEL maintainer="openstreetmap.org@knackich.de"

RUN apt-get update && \
    apt-get -y dist-upgrade && \
    apt-get -y install --no-install-recommends moreutils unzip wget osm2pgsql \
        osmctools postgresql-client-14 npm python3-geopandas \
	python3-sqlalchemy python3-geoalchemy2 python3-pip && \
    apt-get clean && \
    npm install -g @mapbox/geojson-rewind && \
    pip3 install maproulette

WORKDIR /app
ENTRYPOINT ["/bin/bash"]
