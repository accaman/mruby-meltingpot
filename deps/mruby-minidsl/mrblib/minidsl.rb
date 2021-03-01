class MiniDSL
  def self.field(n, opts = {})
    self.fields[n] = opts

    if opts[:as].nil?
      attr_reader n
    else
      define_method(opts[:as]) do
        instance_variable_get(:"@#{n}")
      end
    end
  end

  def self.fields
    @fields ||= {}
  end

  def self.decode(object)
    self.new(object)
  end

  def initialize(opts = {})
    self.class.fields.each do |k, _|
      instance_variable_set(:"@#{k}", nil)
    end

    opts.each do |k, v|
      if self.class.fields.key?(k)
        opts = self.class.fields[k]

        if (m = opts[:load]) && !v.nil?
          v = m.call(v)
        end

        if opts[:freeze]
          v = v.freeze
        end

        instance_variable_set(:"@#{k}", v)
      end
    end
  end

  def validate
    @errors = self.class.fields.inject([]) do |a, i|
      n, opts = *i
      v = instance_variable_get(:"@#{ n }")
      present = opts[:present] || false
      if v.nil? && present
        a << "attribute #{ n } cant'be nil (#{ self.class }\##{ object_id }: #{ to_h })"
      end
      type = opts[:type] || Object
      if v && ! v.is_a?(type)
        a << "attribute #{ n } expected #{ type }, got #{ v.class } (#{ self.class }\##{ object_id }: #{ to_h })"
      end
      a
    end
  end
  attr_reader :errors

  def valid?
    validate.empty?
  end

  def validate!
    raise "Validation failed: #{ errors }" if ! valid?
  end

  def to_h
    self.class.fields.inject({}) do |h, i|
      k, opts = *i

      if opts[:as].nil?
        # XXX, mruby has not `public_send`
        # h[k] = self.public_send(k)
        h[k] = self.send(k)
      else
        # h[k] = self.public_send(opts[:as])
        h[k] = self.send(opts[:as])
      end

      if !h[k].nil? && !h[k].is_a?(Array) && h[k].respond_to?(:to_h)
        h[k] = h[k].to_h
      end

      h
    end
  end

  def ==(other)
    self.to_h == other.to_h
  end
end
