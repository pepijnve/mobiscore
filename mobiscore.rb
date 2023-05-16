require 'net/http'
require 'json'
require 'rexml/document'
require 'stringio'
require 'zlib'

def get(url, headers)
  uri = URI(url)

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  request = Net::HTTP::Get.new(
    uri.request_uri,
    headers
  )

  response = http.request(request)

  if response['content-encoding'] == 'gzip'
    body_io = StringIO.new(response.body)
    gz = Zlib::GzipReader.new(body_io)
    decompressed_body = gz.read
    gz.close
    body = decompressed_body
  else
    body = response.body
  end
  body
end

def get_json(url, headers)
  JSON.parse(get(url, headers))
end

def get_statstical_unit(lat_wgs84, lon_wgs84)
  url = "https://wms.ngi.be/inspire/dgstatistics/service?version=1.3.0&request=GetFeatureInfo&service=WMS"
  url << "&layers=su_vectorstatisticalunits"
  url << "&styles="
  url << "&crs=EPSG:4326"
  url << "&bbox=#{lat_wgs84 - 0.01},#{lon_wgs84 - 0.01},#{lat_wgs84 + 0.01},#{lon_wgs84 + 0.01}"
  url << "&width=100&height=100&format=image/png"
  url << "&query_layers=su_vectorstatisticalunits"
  url << "&info_format=text/xml"
  url << "&i=50"
  url << "&j=50"
  features = get(url, {})

  doc = REXML::Document.new(features)

  # Set the namespace mappings
  namespace = {
    'wfs' => 'http://www.opengis.net/wfs',
    'dgstatistics' => 'http://dgstatistics',
    'gml' => 'http://www.opengis.net/gml'
  }

  # Define the xpath expression to retrieve the value of dgstatistics:T_SEC_NL
  xpath_expr = '//dgstatistics:CS01012019'

  # Find the matching element using the xpath expression and namespace mappings
  REXML::XPath.each(doc, xpath_expr, namespace).map { |e| e.text }
end

street = 'wijnbergenstraat'
number = '97'
city = 'Kessel-Lo'

location_json = get_json(
  "https://loc.geopunt.be/geolocation/location?q=#{URI.encode_www_form_component("#{street} #{number} #{city}")}",
  {
    'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15',
    'Accept' => '*/*',
    'Host' => 'loc.geopunt.be',
    'Sec-Fetch-Site' => 'cross-site',
    'Sec-Fetch-Dest' => 'empty',
    'Sec-Fetch-Mode' => 'cors',
    'Referer' => 'https://mobiscore.omgeving.vlaanderen.be/',
    'Accept-Encoding' => 'gzip, deflate, br',
    'Accept-Language' => 'nl-NL,nl;q=0.9',
    'Origin' => 'https://mobiscore.omgeving.vlaanderen.be'
  })

location = location_json['LocationResult'][0]['Location']
lat_wgs84 = location['Lat_WGS84']
lon_wgs84 = location['Lon_WGS84']
x = location['X_Lambert72']
y = location['Y_Lambert72']

mobiscore_url = "https://mobiscore.omgeving.vlaanderen.be/ajax/get-score?lat=#{lat_wgs84}&lon=#{lon_wgs84}"
mobiscore_json = get_json(
  mobiscore_url,
  {
    'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15',
    'Accept' => '*/*',
    'Host' => 'mobiscore.omgeving.vlaanderen.be',
    'Sec-Fetch-Site' => 'same-origin',
    'Sec-Fetch-Dest' => 'empty',
    'Sec-Fetch-Mode' => 'cors',
    'Referer' => 'https://mobiscore.omgeving.vlaanderen.be/',
    'Accept-Encoding' => 'gzip, deflate, br',
    'Accept-Language' => 'nl-NL,nl;q=0.9',
    'Referer' => 'https://mobiscore.omgeving.vlaanderen.be/'
  }
)

puts "Input"
puts "  Street: #{street}"
puts "  Number: #{number}"
puts "  City: #{city}"
puts

puts "Location"
puts "  lon: #{lon_wgs84}"
puts "  lat: #{lat_wgs84}"
puts "  x: #{x}"
puts "  y: #{y}"
puts

puts "Mobiscore"
mobiscore_json['score']['scores'].each do |key, value|
  puts "  #{key}: #{value}"
end
puts

puts "Statistical units"
get_statstical_unit(lat_wgs84, lon_wgs84).each { |s| puts "  #{s}" }