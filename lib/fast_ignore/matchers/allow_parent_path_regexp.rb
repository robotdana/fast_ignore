# frozen_string_literal: true

class FastIgnore
  module Matchers
    class AllowParentPathRegexp
      def initialize(rule)
        @rule = rule

        freeze
      end

      def squashable_with?(other)
        other.instance_of?(self.class)
      end

      def squash(list)
        return self if list == [self]

        rule = ::Regexp.union(list.map { |l| l.rule }) # rubocop:disable Style/SymbolProc it breaks with protected methods
        self.class.new(rule)
      end

      def dir_only?
        true
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
        "#<AllowParentPathRegexp #{@rule.inspect}>"
      end
      # :nocov:

      def match(candidate)
        :allow if candidate.parent? && @rule.match?(candidate.path)
      end

      protected

      attr_reader :rule
    end
  end
end