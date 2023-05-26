# frozen_string_literal: true

class PathList
  module Matchers
    class Wrapper < Base
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

      def append(pattern)
        appended = @matcher.append(pattern)

        return unless appended

        new_with_matcher(appended)
      end

      def squashable_with?(other)
        other.instance_of?(self.class) &&
          @matcher.squashable_with?(other.matcher)
      end

      def squash(list)
        new_with_matcher(
          @matcher.squash(
            list.map { |l| l.matcher } # rubocop:disable Style/SymbolProc it breaks with protected methods
          )
        )
      end

      protected

      attr_reader :matcher

      private

      def new_with_matcher(matcher)
        # :nocov:
        # none actually hit this super
        self.class.new(matcher)
        # :nocov:
      end
    end
  end
end
