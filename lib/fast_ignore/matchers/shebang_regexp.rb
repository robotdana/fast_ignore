# frozen_string_literal: true

class FastIgnore
  module Matchers
    class ShebangRegexp < Base
      def initialize(rule, negation)
        @rule = rule
        @return_value = negation ? :allow : :ignore

        freeze
      end

      def squashable_with?(other)
        other.instance_of?(ShebangRegexp) &&
          @return_value == other.return_value
      end

      def squash(list)
        self.class.new(::Regexp.union(list.map { |l| l.rule }), @return_value == :allow) # rubocop:disable Style/SymbolProc it breaks with protected methods
      end

      def file_only?
        true
      end

      # :nocov:
      def inspect
        "#<FastIgnore::Matchers::ShebangRegexp #{@return_value} /#{@rule.to_s[26..-4]}/>"
      end
      # :nocov:

      def match(candidate)
        return if candidate.filename.include?('.')

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
