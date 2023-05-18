require_relative 'helpers'

options = {
  :decimal => ',',
  :separator => ';',
  :output => '-',
}
OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename(__FILE__)} [options]"

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
out.puts "su,naam,lon,lat,mobi_totaal,mobi_gezondheid,mobi_onderwijs,mobi_ontspanning,mobi_ov,mobi_winkel"
File.foreach(ARGV[0]) do |line|
  line.strip!
  su, name, lon_wgs84, lat_wgs84 = line.split(',')

  begin
    mobi_score = get_mobi_score(lat_wgs84, lon_wgs84)

    values = [
      su,
      name,
      format_decimal(lon_wgs84, options[:decimal]),
      format_decimal(lat_wgs84, options[:decimal]),
      format_decimal(mobi_score[:total], options[:decimal]),
      format_decimal(mobi_score[:health], options[:decimal]),
      format_decimal(mobi_score[:education], options[:decimal]),
      format_decimal(mobi_score[:culture], options[:decimal]),
      format_decimal(mobi_score[:public_transportation], options[:decimal]),
      format_decimal(mobi_score[:services], options[:decimal])
    ]
  rescue => e
    STDERR.puts "Line #{line_no}: #{line}"
    STDERR.puts "  #{e}"
    values = [
      su,
      name,
      format_decimal(lon_wgs84, options[:decimal]),
      format_decimal(lat_wgs84, options[:decimal]),
      nil,
      nil,
      nil,
      nil,
      nil,
      nil
    ]
  end

  out.puts values.map { |v| quote(v) }.join(options[:separator])

  line_no = line_no + 1
end

if options[:output] != '-'
  out.close
end