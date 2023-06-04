# frozen_string_literal: true

class PathList
  module Matchers
    class Base
      def dir_only?
        false
      end

      def file_only?
        false
      end

      def implicit?
        false
      end

      def squashable_with?(other)
        equal?(other)
      end

      def squash(_)
        self
      end

      def append(_)
        nil
      end

      def weight
        0
      end

      def removable?
        false
      end

      def match(_)
        nil
      end

      def eql?(other)
        self.class == other.class &&
          (instance_variables | other.instance_variables).all? do |var|
            instance_variable_get(var) == other.instance_variable_get(var)
          end
      end
      alias_method :==, :eql?

      def hash
        self.class.hash
      end
    end
  end
end
