require 'json'
require 'net/http'
require 'optparse'
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

def get_google_location(location, google_api_key)
  location_json = get_json(
    "https://maps.googleapis.com/maps/api/geocode/json?key=#{google_api_key}&address=#{URI.encode_www_form_component(location)}",
    {
      'Accept' => '*/*',
      'Accept-Encoding' => 'gzip, deflate, br'
    })
  location_result = location_json['results'][0]
  if location_result
    address = location_result['formatted_address']
    geometry = location_result['geometry']['location']
    { :address => address, :lat => geometry['lat'], :lon => geometry['lng'] }
  else
    nil
  end
end

def get_geopunt_location(location)
  location_json = get_json(
    "https://loc.geopunt.be/geolocation/location?q=#{URI.encode_www_form_component(location)}",
    {
      'Accept' => '*/*',
      'Accept-Encoding' => 'gzip, deflate, br',
      'Accept-Language' => 'nl-NL,nl;q=0.9'
    })
  location_result = location_json['LocationResult'][0]
  if location_result
    geometry = location_result['Location']
    { :address => "#{location_result['FormattedAddress']}, Belgium", :lat => geometry['Lat_WGS84'], :lon => geometry['Lon_WGS84'] }
  else
    nil
  end
end

def get_geopunt_suggestion(location)
  location_json = get_json(
    "https://loc.geopunt.be/geolocation/suggestion?q=#{URI.encode_www_form_component(location)}",
    {
      'Accept' => '*/*',
      'Accept-Encoding' => 'gzip, deflate, br',
      'Accept-Language' => 'nl-NL,nl;q=0.9'
    })
  location_json['SuggestionResult'][0]
end

def get_mobi_score(lat_wgs84, lon_wgs84)
  mobi_score_url = "https://mobiscore.omgeving.vlaanderen.be/ajax/get-score?lat=#{lat_wgs84}&lon=#{lon_wgs84}"
  mobi_score_json = get_json(
    mobi_score_url,
    {
      'Accept' => '*/*',
      'Accept-Encoding' => 'gzip, deflate, br',
      'Accept-Language' => 'nl-NL,nl;q=0.9',
      'Referer' => 'https://mobiscore.omgeving.vlaanderen.be/'
    }
  )
  mobi_score = mobi_score_json['score']['scores']

  {
    :total => mobi_score['totaal'],
    :health => mobi_score['gezondheid'],
    :education => mobi_score['onderwijs'],
    :culture => mobi_score['ontspanning_sport_cultuur'],
    :public_transportation => mobi_score['ov'],
    :services => mobi_score['winkels_en_diensten']
  }
end

def format_decimal(decimal, decimal_point)
  if decimal
    decimal.to_s.gsub('.', decimal_point)
  else
    decimal
  end
end

def quote(value)
  if value && value !~ /".*"/
    "\"#{value}\""
  else
    value
  end
end