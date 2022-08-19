# frozen_string_literal: true

class FastIgnore
  module Matchers
    class PathRegexp
      attr_reader :dir_only
      alias_method :dir_only?, :dir_only
      undef :dir_only

      def initialize(rule, squashable, dir_only, allow)
        @rule = rule
        @dir_only = dir_only
        @squashable = squashable
        @return_value = allow ? :allow : :ignore

        freeze
      end

      def squashable_with?(other)
        @squashable &&
          other.instance_of?(self.class) &&
          other.squashable? &&
          @return_value == other.return_value &&
          @dir_only == other.dir_only?
      end

      def squash(list)
        return self if list == [self]

        rule = ::Regexp.union(list.map { |l| l.rule }) # rubocop:disable Style/SymbolProc it breaks with protected methods
        self.class.new(rule, @squashable, @dir_only, @return_value == :allow)
      end

      def file_only?
        false
      end

      def weight
        1
      end

      def removable?
        false
      end

      # :nocov:
      def inspect
        "#<PathRegexp #{@return_value} #{'dir_only ' if @dir_only}#{@rule.inspect}>"
      end
      # :nocov:

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
