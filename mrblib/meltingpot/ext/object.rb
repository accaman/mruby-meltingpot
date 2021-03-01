# adapted from rails <github.com/rails/rails>
# Copyright (c) 2007-2016 Nick Kallen, Bryan Helmkamp, Emilio Tagua, Aaron Patterson
# Used under the MIT License:
# https://opensource.org/licenses/mit-license.php
class Object
  def try(*a, &b)
    try!(*a, &b) if a.empty? || respond_to?(a.first)
  end

  def try!(*a, &b)
    if a.empty? && block_given?
      if b.arity.zero?
        instance_eval(&b)
      else
        yield self
      end
    else
      send(*a, &b)
    end
  end
end

class NilClass
  def try(*args)
    nil
  end

  def try!(*args)
    nil
  end
end

class Object
  def blank?
    respond_to?(:empty?) ? !!empty? : !self
  end

  def present?
    !blank?
  end
end

# @see https://dev.classmethod.jp/articles/ruby-object-to-boolean/
class Object
  def to_b
    compare_value = self.class == String ? self.downcase : self
    case compare_value
      when "yes", "true", "ok", true, "1", 1, :true, :ok, :yes
        true
      else
        false
    end
  end
end