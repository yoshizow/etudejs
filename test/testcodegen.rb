# Load js/*.js and parse, codegen them

SCRIPTDIR = File.dirname($0)

$LOAD_PATH << SCRIPTDIR + '/..'

require 'parser'
require 'function'
require 'codegen'

TESTDIR = SCRIPTDIR + '/js'

def test(file)
  puts "File: #{file}"
  src = IO.read(file)
  parser = JSParser.new
  # parser.yydebug = true
  begin
    ast = parser.parse(src)
  rescue ParseError
    puts 'parse error'
  end

  global_code_func = JSUserFunction.new()
  codegen = CodeGenVisitor.new(global_code_func)
  ast.accept(codegen)
  print global_code_func.to_s
end

if ARGV.size != 0
  files = ARGV
else
  files = Dir.glob("#{TESTDIR}/**/*.js")
end
files.each do |file|
  test(file)
end
