class JSValue
  # type: one of
  #   :undefined
  #   :null
  #   :boolean
  #   :number
  #   :string
  #   :object
  #   :identifier    # internal type

  def initialize(type, value)
    @type = type
    @value = value
  end

  attr_reader :type
  attr_reader :value

  def add(other)
    if @type == :number && other.type == :number
      JSValue.new(:number, @value + other.value)
    else
      raise 'implement me'
    end
  end

  def sub(other)
    if @type == :number && other.type == :number
      JSValue.new(:number, @value - other.value)
    else
      raise 'implement me'
    end
  end

  def mul(other)
    if @type == :number && other.type == :number
      JSValue.new(:number, @value * other.value)
    else
      raise 'implement me'
    end
  end

  def div(other)
    if @type == :number && other.type == :number
      JSValue.new(:number, @value / other.value)
    else
      raise 'implement me'
    end
  end

  def neg()
    if @type == :number
      JSValue.new(:number, - @value)
    else
      raise 'implement me'
    end
  end

  def to_s
    '#<JSValue ' + case @type
    when :undefined
      'undefined'
    when :null
      'null'
    when :string
      @value.inspect
    else
      @value.to_s
    end + '>'
  end

  UNDEFINED = JSValue.new(:undefined, nil)
  NULL = JSValue.new(:null, nil)
  TRUE = JSValue.new(:boolean, true)
  FALSE = JSValue.new(:boolean, false)
end
