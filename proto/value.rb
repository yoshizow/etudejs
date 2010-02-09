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

  # ECMA-262 3rd 11.8.5 The Abstract Relational Comparison Algorithm
  def compare(other)
    x = self.to_primitive(:number)
    y = other.to_primitive(:number)
    if x.type == :string && y.type == :string
      raise 'implement me'
    else
      x = x.to_number()
      y = y.to_number()
      # TODO: check NaN, -0, +0, +Inf, -Inf, etc
      if x.value < y.value
        return JSValue::TRUE
      else
        return JSValue::FALSE
      end
    end
  end

  # ECMA-262 3rd 9.1 ToPrimitive() operator
  def to_primitive(hint)
    if @type == :object
      raise 'implement me'
    else
      return self
    end
  end

  # ECMA-262 3rd 9.2 ToBoolean() operator
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

  # ECMA-262 3rd 9.3 ToNumber() operator
  def to_number()
    case @type
    when :undefined
      raise 'implement me'
    when :null
      JSValue.new_number(0)
    when :boolean
      if @value
        JSValue.new_number(1)
      else
        JSValue.new_number(0)
      end
    when :number
      self
    when :string
      raise 'implement me'
    when :object
      raise 'implement me'
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
