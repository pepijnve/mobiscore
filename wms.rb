require 'rest-client'

url = 'https://wms.ngi.be/inspire/dgstatistics/service'

params = {
  service: 'WMS',
  version: '1.3.0',
  request: 'GetMap',
  layers: 'LayerName',
  format: 'image/png',
  transparent: true,
  width: 400,
  height: 400,
  srs: 'EPSG:4326'
}

# Replace the following coordinates with your desired bounding box
lon = 4.748561208729297
lat = 50.90367347197818

longitude_min = lon - 0.5
latitude_min = lat - 0.5
longitude_max = lon + 0.5
latitude_max = lat + 0.5

params[:bbox] = "#{longitude_min},#{latitude_min},#{longitude_max},#{latitude_max}"

response = RestClient.get(url, params: params)

# Save the response to a file
File.open('map.png', 'wb') do |file|
  file.write(response.body)
end