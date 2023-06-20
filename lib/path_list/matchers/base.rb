# frozen_string_literal: true

class PathList
  module Matchers
    class Base
      include ComparableInstance

      class << self
        alias_method :build, :new
      end

      def polarity
        :mixed
      end

      alias_method :original_inspect, :inspect
      alias_method :name, :class

      def inspect
        "#{self.class}.new"
      end

      def squashable_with?(other)
        equal?(other)
      end

      def squash(_)
        self
      end

      def weight
        1
      end

      def match(_)
        nil
      end
    end
  end
end
