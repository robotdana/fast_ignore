# frozen_string_literal: true

class FastIgnore
  module Matchers
    class List < Base
      def initialize(matchers)
        @matchers = matchers

        freeze
      end

      def squashable_with?(other)
        # :nocov:
        other.instance_of?(self.class)
        # :nocov:
      end

      def squash(list)
        # :nocov:
        self.class.new(list.flat_map { |l| l.matchers }) # rubocop:disable Style/SymbolProc it breaks with protected methods
        # :nocov:
      end

      def weight
        @matchers.sum(&:weight)
      end

      def file_only?
        # :nocov:
        @matchers.all?(&:file_only?)
        # :nocov:
      end

      def dir_only?
        # :nocov:
        @matchers.all?(&:dir_only?)
        # :nocov:
      end

      def removable?
        @matchers.empty? || @matchers.all?(&:removable?)
      end

      def implicit?
        @matchers.all?(&:implicit?)
      end

      protected

      attr_reader :matchers
    end
  end
end
