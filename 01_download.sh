#!/bin/bash -e

cd data
echo ">>> Downloading Census 2011 data"
wget 'https://www.zensus2011.de/SharedDocs/Downloads/DE/Pressemitteilung/DemografischeGrunddaten/csv_Bevoelkerung_100m_Gitter.zip?__blob=publicationFile&v=3' \
    --timestamping
ln -sf csv_Bevoelkerung_100m_Gitter.zip\?* csv_Bevoelkerung_100m_Gitter.zip
unzip -o csv_Bevoelkerung_100m_Gitter.zip

echo ">>> Downloading OpenStreetMap dump for Germany"
wget 'http://download.geofabrik.de/europe/germany-latest.osm.pbf' \
    --timestamping
