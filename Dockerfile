FROM debian:testing
LABEL maintainer="openstreetmap.org@knackich.de"

RUN apt-get update && \
    apt-get -y dist-upgrade && \
    apt-get -y install --no-install-recommends moreutils unzip wget osm2pgsql \
        osmctools postgresql-client-13 npm && \
    apt-get clean && \
    npm install -g @mapbox/geojson-rewind

WORKDIR /app
ENTRYPOINT ["/bin/bash"]
