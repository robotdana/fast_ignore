# frozen_string_literal: true

class PathList
  class Matcher
    AllowAnyDir = Matcher.new

    def AllowAnyDir.match(candidate)
      :allow if candidate.directory?
    end

    def AllowAnyDir.inspect
      'PathList::Matcher::AllowAnyDir'
    end

    def AllowAnyDir.polarity
      :allow
    end

    def AllowAnyDir.squashable_with?(other)
      equal?(other) || other.instance_of?(MatchIfDir)
    end

    def AllowAnyDir.squash(list, preserve_order)
      return self unless preserve_order

      MatchIfDir.build(LastMatch.build(list.map { |l| l == self ? Allow : l.matcher }))
    end

    def AllowAnyDir.dir_matcher
      Allow
    end

    def AllowAnyDir.file_matcher
      Blank
    end

    AllowAnyDir.freeze
  end
end
