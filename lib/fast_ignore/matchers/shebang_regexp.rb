# frozen_string_literal: true

class FastIgnore
  module Matchers
    class ShebangRegexp
      def initialize(rule, negation)
        @rule = rule
        @return_value = negation ? :allow : :ignore

        freeze
      end

      def squashable_with?(other)
        other == Unmatchable || (
          other.instance_of?(ShebangRegexp) &&
            @return_value == other.return_value
        )
      end

      def squash(list)
        list -= [Unmatchable]
        return self if list == [self]

        self.class.new(::Regexp.union(list.map { |l| l.rule }), @return_value == :allow) # rubocop:disable Style/SymbolProc it breaks with protected methods
      end

      def file_only?
        true
      end

      def dir_only?
        false
      end

      def removable?
        false
      end

      # :nocov:
      def inspect
        "#<ShebangRegexp #{@return_value} /#{@rule.to_s[26..-4]}/>"
      end
      # :nocov:

      def match?(candidate)
        return false if candidate.filename.include?('.')

        @return_value if candidate.first_line.match?(@rule)
      end

      def weight
        2
      end

      protected

      attr_reader :return_value
      attr_reader :rule
    end
  end
end
