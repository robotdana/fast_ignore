# frozen_string_literal: true

class PathList
  module ComparableInstance
    def eql?(other)
      self.class == other.class &&
        instance_variables.all? do |var|
          instance_variable_get(var) == other.instance_variable_get(var)
        end
    end
    alias_method :==, :eql?

    def hash
      self.class.hash
    end
  end
end
