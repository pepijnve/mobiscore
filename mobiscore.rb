require 'net/http'
require 'json'
require 'zlib'
require 'stringio'

def do_get(url, headers)
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

  JSON.parse(body)
end

street = 'wijnbergenstraat'
number = '97'
city = 'Kessel-Lo'

location_json = do_get(
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

mobiscore_url = "https://mobiscore.omgeving.vlaanderen.be/ajax/get-score?lat=#{lat_wgs84}&lon=#{lon_wgs84}"
mobiscore_json = do_get(
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
puts "#{street} #{number}, #{city}"
puts

puts "Location"
puts "lon: #{lon_wgs84}"
puts "lat: #{lat_wgs84}"
puts

puts "Mobiscore"
mobiscore_json['score']['scores'].each do |key, value|
  puts "#{key}: #{value}"
end
