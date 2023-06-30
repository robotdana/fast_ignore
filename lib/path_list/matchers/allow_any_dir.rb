# frozen_string_literal: true

class PathList
  module Matchers
    AllowAnyDir = Base.new

    class << AllowAnyDir
      def match(candidate)
        :allow if candidate.directory?
      end

      def inspect
        'PathList::Matchers::AllowAnyDir'
      end

      def polarity
        :allow
      end

      def squashable_with?(other)
        equal?(other) || other.instance_of?(MatchIfDir)
      end

      def squash(list, preserve_order)
        return self unless preserve_order

        MatchIfDir.build(LastMatch.build(list.map { |l| l == self ? Allow : l.matcher }))
      end

      def dir_matcher
        Allow
      end

      def file_matcher
        Blank
      end
    end

    AllowAnyDir.freeze
  end
end
