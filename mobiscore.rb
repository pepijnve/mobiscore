require_relative 'helpers'

def get_info(location, google_api_key)
  location_result = get_geopunt_location(location)

  if location_result.nil?
    suggestion = get_geopunt_suggestion(location)
    if suggestion
      STDERR.puts "Trying '#{suggestion}' instead of '#{location}'"
      location_result = get_geopunt_location(suggestion)
    end
  end

  if location_result.nil? && google_api_key
    location_result = get_google_location(location, google_api_key)
  end

  if location_result.nil?
    raise "Could not determine location '#{location}'"
  end

  address = location_result[:address]
  lat_wgs84 = location_result[:lat]
  lon_wgs84 = location_result[:lon]

  mobi_score = get_mobi_score(lat_wgs84, lon_wgs84)

  statistical_units = get_statstical_unit(lat_wgs84, lon_wgs84)

  {
    :address => address,
    :lat => lat_wgs84,
    :lon => lon_wgs84,
    :mobi_score => mobi_score,
    :statistical_units => statistical_units
  }
end

options = {
  :fields => [0, 1, 2],
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

  opts.on("-g", "--google_api_key [KEY]", String,
          "Specify a Google API key to use the Google Geolocation API. (default none)") do |key|
    options[:google_api_key] = key
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

  begin
    score = get_info(address, options[:google_api_key])

    mobi_score = score[:mobi_score]
    values = [
      score[:address],
      format_decimal(score[:lon], options[:decimal]),
      format_decimal(score[:lat], options[:decimal]),
      format_decimal(mobi_score[:total], options[:decimal]),
      format_decimal(mobi_score[:health], options[:decimal]),
      format_decimal(mobi_score[:education], options[:decimal]),
      format_decimal(mobi_score[:culture], options[:decimal]),
      format_decimal(mobi_score[:public_transportation], options[:decimal]),
      format_decimal(mobi_score[:services], options[:decimal]),
      score[:statistical_units].first
    ]
  rescue => e
    STDERR.puts "Line #{line_no}: #{line}"
    STDERR.puts "  #{e}"
    values = [address, '', '', '', '', '', '', '', '', '']
  end

  out.puts values.map { |v| quote(v) }.join(options[:separator])

  line_no = line_no + 1
end

if options[:output] != '-'
  out.close
end