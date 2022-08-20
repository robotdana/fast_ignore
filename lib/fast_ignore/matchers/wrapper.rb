# frozen_string_literal: true

class FastIgnore
  module Matchers
    class Wrapper
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
        # :nocov:
        # TODO: consistent api
        @matcher.dir_only?
        # :nocov:
      end

      def file_only?
        # :nocov:
        # TODO: consistent api
        @matcher.file_only?
        # :nocov:
      end

      def squashable_with?(other)
        other.instance_of?(self.class) &&
          @matcher.squashable_with?(other.matcher)
      end

      def squash(list)
        # :nocov:
        # TODO: consistent api
        self.class.build(squashed_matcher(list))
        # :nocov:
      end

      protected

      def squash_matchers(list)
        # :nocov:
        # TODO: consistent api
        @matcher.squash(list.map { |l| l.matcher }) # rubocop:disable Style/SymbolProc it breaks with protected methods
        # :nocov:
      end

      attr_reader :matcher
    end
  end
end
