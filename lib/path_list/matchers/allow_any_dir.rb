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
        equal?(other) ||
          (other.instance_of?(MatchIfDir) && other.polarity == :allow)
      end

      def squash(_)
        self
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
