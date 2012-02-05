# Load js/*.js and parse, codegen them

SCRIPTDIR = File.dirname($0)

$LOAD_PATH << SCRIPTDIR + '/..'

require 'parser'
require 'function'
require 'codegen'
require 'context'
require 'interpreter'

TESTDIR = SCRIPTDIR + '/js'

def log(str)
  puts str.to_s
  return JSValue::UNDEFINED
end

def setup_globalobj(context)
  func = JSFunctionObject.new(JSNativeFunction.new(self.method(:log)))
  context.global_object.put(JSValue.new(:string, 'log'), func)
end

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

  context = JSContext.new
  setup_globalobj(context)
  interp = JSInterpreter.new(context)
  interp.execute(global_code_func)
end

if ARGV.size != 0
  files = ARGV
else
  files = Dir.glob("#{TESTDIR}/**/*.js")
end
files.each do |file|
  test(file)
end
