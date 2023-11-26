# frozen_string_literal: true

class PathList
  class PatternParser
    # Match within the shebang of extensionless files
    #
    # This is intended for matching files in particular scripting languages
    # when there is no file extension to otherwise indicate the language
    #
    # The patterns will match when the first line of a file starts with `#!`,
    # and the pattern is a whole-word sub-string match.
    #
    # This format will be used by PathList for {PathList#only} and {PathList#ignore} with `format: :shebang`
    #
    # When used with {PathList#only}, it will also allow all potentially containing directories (with a lower priority).
    #
    # @example
    #   PathList.only('ruby', format: :shebang, root: 'scripts').to_a
    #   # will match files in scripts directory starting with `#!/bin/ruby` or `#!/usr/bin/ruby` or `#!/usr/bin/ruby -w`
    #   # but wouldn't match jruby as it's not a whole-word match.
    #   # and wouldn't match files starting with `i promise this is a ruby file` as that isn't starting with `#!`
    class Shebang
      # @api private
      # @param pattern [String]
      # @param polarity [:ignore, :allow]
      # @param root [String]
      def initialize(pattern, polarity, root)
        @pattern = pattern
        @polarity = polarity
        @root = root

        @root_re = TokenRegexp::Path.new_from_path(root, tail: [:dir, :any_dir])
      end

      # @api private
      # @return [PathList::Matcher]
      def matcher
        shebang = @pattern.delete_prefix('#!').strip

        regexp = TokenRegexp.new([:start_anchor, '#!', :any])
        # we only want word boundary anchors if we are going from word characters to non-word
        regexp.append_part :word_boundary if shebang.match?(/\A\w/)
        regexp.append_string shebang
        regexp.append_part :word_boundary if shebang.match?(/\w\z/)

        Matcher::MatchUnlessDir.build(
          Matcher::PathRegexpWrapper.build(
            # TODO: consider if this needs splitting, i don't think it does?
            Regexp.new("\\A#{Regexp.escape(@root)}/(?:.*/)?[^/\\.]*\\z", CanonicalPath.case_insensitive? ? 1 : 0),
            Matcher::ShebangRegexp.build([regexp.parts], @polarity)
          )
        )
      end

      # @api private
      # @return [PathList::Matcher]
      def implicit_matcher
        ancestors = @root_re.ancestors

        exact, regexp = ancestors.partition(&:exact_path?)
        exact = Matcher::ExactString.build(exact.map(&:to_s), :allow)
        regexp = Matcher::PathRegexp.build(regexp.map(&:parts), :allow)

        Matcher::MatchIfDir.build(Matcher::Any.build([exact, regexp]))
      end
    end
  end
end
