require 'parser'

parser = JSParser.new()
while true
  print '> '; $stdout.flush
  str = $stdin.gets
  break if str == nil
  begin
    p parser.parse(str).to_s
  rescue ParseError
    puts 'parse error'
  end
end
