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

def get_mobi_score(location)
  location_json = get_json(
    "https://loc.geopunt.be/geolocation/location?q=#{URI.encode_www_form_component(location)}",
    {
      'Accept' => '*/*',
      'Accept-Encoding' => 'gzip, deflate, br',
      'Accept-Language' => 'nl-NL,nl;q=0.9'
    })

  location_result = location_json['LocationResult'][0]
  if location_result.nil?
    raise "Could not determine location '#{location}'"
  end

  location = location_result['Location']
  lat_wgs84 = location['Lat_WGS84']
  lon_wgs84 = location['Lon_WGS84']
  x = location['X_Lambert72']
  y = location['Y_Lambert72']

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

  statistical_units = get_statstical_unit(lat_wgs84, lon_wgs84)

  return {
    :lat => lat_wgs84,
    :lon => lon_wgs84,
    :x => x,
    :y => y,
    :mobi_score => {
      :total => mobi_score['totaal'],
      :health => mobi_score['gezondheid'],
      :education => mobi_score['onderwijs'],
      :culture => mobi_score['ontspanning_sport_cultuur'],
      :public_transportation => mobi_score['ov'],
      :services => mobi_score['winkels_en_diensten']
    },
    :statistical_units => statistical_units
  }
end

def format_decimal(decimal, decimal_point)
  if decimal
    decimal.to_s.gsub('.', decimal_point)
  else
    decimal
  end
end

options = {
  :fields => [0,1,2],
  :decimal => ',',
  :separator => ';',
  :output => '-',
}
OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename(__FILE__)} [options]"

  opts.on("-f", "--fields [FIELD_NUMBERS]", String,
          "Specify input field numbers to use for location queries (default 1,2,3)") do |s|
    options[:fields] = s.split(',').map { |f| f.strip.to_i - 1 }
  end

  opts.on("-s", "--separator [SEP]", String,
            "Specify value separator (default ;)") do |s|
    options[:separator] = s
  end

  opts.on("-d", "--decimal [DEC]", String,
          "Specify decimal point (default ,)") do |s|
    options[:decimal] = s
  end

  opts.on("-o", "--output [FILE]", String,
          "Specify output file. (default -)") do |out_file|
    options[:output] = out_file
  end
end.parse!

if options[:output] == '-'
  out = STDOUT
else
  out = File.open(options[:output], "w")
end

line_no = 1
out.puts "adres,lon,lat,mobi_totaal,mobi_gezondheid,mobi_onderwijs,mobi_ontspanning,mobi_ov,mobi_winkel,su"
File.foreach(ARGV[0]) do |line|
  line.strip!
  fields = line.split(options[:separator])
  address = options[:fields].map { |i| fields[i] }.join(' ')

  values = [
    address
  ]

  begin
    score = get_mobi_score(address)

    mobi_score = score[:mobi_score]
    values.concat([
      format_decimal(score[:lon], options[:decimal]),
      format_decimal(score[:lat], options[:decimal]),
      format_decimal(mobi_score[:total], options[:decimal]),
      format_decimal(mobi_score[:health], options[:decimal]),
      format_decimal(mobi_score[:education], options[:decimal]),
      format_decimal(mobi_score[:culture], options[:decimal]),
      format_decimal(mobi_score[:public_transportation], options[:decimal]),
      format_decimal(mobi_score[:services], options[:decimal]),
      "\"#{score[:statistical_units].first}\""
    ])
  rescue => e
    STDERR.puts "Line #{line_no}: #{line}"
    STDERR.puts "  #{e}"
    values.concat ['', '', '', '', '', '', '', '', '']
  end

  out.puts values.join(options[:separator])

  line_no = line_no + 1
end

if options[:output] != '-'
  out.close
end