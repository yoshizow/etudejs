class JSValue
  # type: one of
  #   :undefined
  #   :null
  #   :boolean
  #   :number
  #   :string
  #   :object
  #   :identifier    # internal type

  def self.new_number(value)
    self.new(:number, value)
  end

  def self.new_string(value)
    self.new(:string, value)
  end

  def self.new_identifier(value)
    self.new(:identifier, value)
  end

  # Note: don't call new() directly!
  def initialize(type, value)
    @type = type
    @value = value
  end

  attr_reader :type, :value

  def add(other)
    if @type == :number && other.type == :number
      JSValue.new_number(@value + other.value)
    else
      raise 'implement me'
    end
  end

  def sub(other)
    if @type == :number && other.type == :number
      JSValue.new_number(@value - other.value)
    else
      raise 'implement me'
    end
  end

  def mul(other)
    if @type == :number && other.type == :number
      JSValue.new_number(@value * other.value)
    else
      raise 'implement me'
    end
  end

  def div(other)
    if @type == :number && other.type == :number
      JSValue.new_number(@value / other.value)
    else
      raise 'implement me'
    end
  end

  def neg()
    if @type == :number
      JSValue.new_number(- @value)
    else
      raise 'implement me'
    end
  end

  # ToBoolean() operator defined in ECMA-262
  def to_boolean()
    case @type
    when :undefined
      JSValue::FALSE
    when :null
      JSValue::FALSE
    when :boolean
      self
    when :number
      # TODO: implment for NaN, -0
      if @value == 0
        JSValue::FALSE
      else
        JSValue::TRUE
      end
    when :string
      raise 'implement me'
    when :object
      JSValue::TRUE
    else
      raise 'notreached'
    end
  end

  def to_s
    '#<JSValue ' +
      case @type
      when :undefined
        'undefined'
      when :null
        'null'
      when :string
        @value.inspect
      else
        @value.to_s
      end +
      '>'
  end

  UNDEFINED = JSValue.new(:undefined, nil)
  NULL = JSValue.new(:null, nil)
  TRUE = JSValue.new(:boolean, true)
  FALSE = JSValue.new(:boolean, false)
end
