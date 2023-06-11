# frozen_string_literal: true

class PathList
  module Matchers
    class PathRegexp < Base
      attr_reader :dir_only
      alias_method :dir_only?, :dir_only
      undef :dir_only

      attr_reader :implicit
      alias_method :implicit?, :implicit
      undef :implicit

      def initialize(rule, squashable, dir_only, allow, implicit)
        @rule = rule
        @dir_only = dir_only
        @implicit = implicit
        @squashable = squashable
        @return_value = allow ? :allow : :ignore

        freeze
      end

      def squashable_with?(other)
        @squashable &&
          other.instance_of?(self.class) &&
          other.squashable? &&
          @return_value == other.return_value &&
          @implicit == other.implicit? &&
          @dir_only == other.dir_only?
      end

      def squash(list)
        self.class.new(
          ::Regexp.union(list.map { |l| l.rule }), # rubocop:disable Style/SymbolProc it breaks with protected methods,
          @squashable,
          @dir_only,
          @return_value == :allow,
          @implicit
        )
      end

      def weight
        1
      end

      def polarity
        @return_value
      end

      def inspect
        "#<#{self.class} #{'dir_only ' if @dir_only}#{@return_value.inspect} #{@rule.inspect}>"
      end

      def match(candidate)
        @return_value if @rule.match?(candidate.path)
      end

      protected

      attr_reader :rule
      attr_reader :return_value

      attr_reader :squashable
      alias_method :squashable?, :squashable
      undef :squashable
    end
  end
end
