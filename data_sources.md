# Data Retrieval

## Determine Address Coordinates

- Read addresses from input CSV line
- Use Geopunt geolocation API to retrieve EPSG:4326 (WGS84) lon/lat coordinates
- Try Geopunt suggestion API as first fallback
- Use Google Maps geolocation API as final fallback

## Determine Statistical Unit for Coordinate

- Perform a GetFeatureInfo query against the NGI WMS service
- A small EPSG:4326 lon/lat square centered on the provided coordinate is used as map query parameter. The center pixel coordinate of this square is used for the feature query. This is a rather crude query approach, but it's good enough for this project.

## Determine Mobiscore for Coordinate

- Query the Mobiscore backend using the given EPSG:4326 lon/lat coordinate

## Determine Mobiscore for Statistical Unit

- Extract statistical unit boundary from spatialite database
- Calculate centroid in EPSG:3812 (ETRS89 / Belgian Lambert 2008)
- Transform EPSG:3812 coordinate to EPSG:4326
- Determine Mobiscore for computed EPSG:4326 coordinate

# Data Sources

## Addresses

Provided from an internal database

## Geolocation

Flemish government geolocation service https://overheid.vlaanderen.be/crab-geolocation

Google Maps geolocation API as fallback 

## Statistical Sectors

Lookup via the NGI WMS service at https://wms.ngi.be/inspire/dgstatistics/service?request=GetCapabilities&service=WMS&version=1.3.0

Database from https://publish.geo.be/geonetwork/srv/eng/catalog.search#/metadata/4d8e0053-fdf5-42e4-a359-1a3386d95899

## Mobiscore

Retrieved via https://mobiscore.omgeving.vlaanderen.be