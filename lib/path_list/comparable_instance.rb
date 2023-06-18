# frozen_string_literal: true

class PathList
  module ComparableInstance
    def eql?(other, except: nil)
      self.class == other.class &&
        (instance_variables - Array(except)).all? do |var|
          instance_variable_get(var) == other.instance_variable_get(var)
        end
    end
    alias_method :==, :eql?

    def hash
      self.class.hash
    end
  end
end
