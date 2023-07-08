# frozen_string_literal: true

class PathList
  # @api private
  class Matcher
    # Matcher that allows every directory
    # @api private
    AllowAnyDir = Matcher.new

    # @api private
    def AllowAnyDir.match(candidate)
      :allow if candidate.directory?
    end

    # @api private
    def AllowAnyDir.inspect
      'PathList::Matcher::AllowAnyDir'
    end

    # @api private
    def AllowAnyDir.polarity
      :allow
    end

    # @api private
    def AllowAnyDir.squashable_with?(other)
      equal?(other) || other.instance_of?(MatchIfDir)
    end

    # @api private
    def AllowAnyDir.squash(list, preserve_order)
      return self unless preserve_order

      MatchIfDir.build(LastMatch.build(list.map { |l| l == self ? Allow : l.matcher }))
    end

    # @api private
    def AllowAnyDir.dir_matcher
      Allow
    end

    # @api private
    def AllowAnyDir.file_matcher
      Blank
    end

    AllowAnyDir.freeze
  end
end
