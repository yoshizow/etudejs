# Load js/*.js and just parse it

SCRIPTDIR = File.dirname($0)

$LOAD_PATH << SCRIPTDIR + '/..'

require 'parser'

TESTDIR = SCRIPTDIR + '/js'

def test(file)
  puts "File: #{file}"
  src = IO.read(file)
  parser = JSParser.new
  # parser.yydebug = true
  begin
    puts parser.parse(src).to_s
  rescue ParseError
    puts 'parse error'
  end
end

if ARGV.size != 0
  files = ARGV
else
  files = Dir.glob("#{TESTDIR}/**/*.js")
end
files.each do |file|
  test(file)
end
