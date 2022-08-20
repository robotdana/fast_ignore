# frozen_string_literal: true

class FastIgnore
  module Matchers
    class Wrapper
      def self.build(matcher)
        new(matcher)
      end

      def initialize(matcher)
        @matcher = matcher

        freeze
      end

      def weight
        @matcher.weight
      end

      def implicit?
        @matcher.implicit?
      end

      def removable?
        @matcher.removable?
      end

      def dir_only?
        @matcher.dir_only?
      end

      def file_only?
        @matcher.file_only?
      end

      def squashable_with?(other)
        other.instance_of?(self.class) &&
          @matcher.squashable_with?(other.matcher)
      end

      def squash(list)
        self.class.build(squashed_matcher(list))
      end

      def match(_candidate)
        raise NoMethodError
      end

      protected

      def squash_matchers(list)
        @matcher.squash(list.map { |l| l.matcher }) # rubocop:disable Style/SymbolProc it breaks with protected methods
      end

      attr_reader :matcher
    end
  end
end
