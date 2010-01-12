class JSLexer
  KEYWORDS = %w[var function return]

  def initialize(input)
    scanner = StringScanner.new(input)
    @tokens = []
    until scanner.eos?
      case
      when scanner.skip(/\s+/)
        ;
      when scanner.skip(%r!/\*.*?\*/!m)
        ;
      when scanner.skip(%r!//.*$!)
        ;
      when scanner.scan(/\d+/)
        @tokens.push [:NUMBER, scanner[0].to_i]
      when scanner.scan(/(#{KEYWORDS.join('|')})\b/o)
        @tokens.push [scanner[0], scanner[0]]
      when scanner.scan(/[$_A-Za-z][$_A-Za-z0-9]*\b/)
        @tokens.push [:IDENTIFIER, scanner[0]]
      else
        s = scanner.getch
        @tokens.push [s, s]
      end
    end
    @tokens.push [false, nil]
  end

  # Returns racc form of token e.g. [:NUMBER, 123]
  def next_token
    @tokens.shift
  end
end
