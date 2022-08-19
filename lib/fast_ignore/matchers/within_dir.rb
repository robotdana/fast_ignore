# frozen_string_literal: true

class FastIgnore
  module Matchers
    class WithinDir
      attr_reader :dir

      def initialize(matchers, dir)
        @matcher = MatchByType.new(matchers)
        @dir = dir

        freeze
      end

      def weight
        @matcher.weight
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
        other.instance_of?(WithinDir) && @dir == other.dir
      end

      def squash(list)
        self.class.new(list.map { |l| l.matcher }, @dir) # rubocop:disable Style/SymbolProc it breaks with protected methods
      end

      def match(candidate)
        candidate.with_path_relative_to(@dir) do
          @matcher.match(candidate)
        end
      end

      protected

      attr_reader :matcher
    end
  end
end
