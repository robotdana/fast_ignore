# frozen_string_literal: true

class PathList
  class PatternParser
    # This pattern is a case-insensitive exact string match
    #
    # This format will be used by PathList for {PathList#only} and {PathList#ignore} with `format: :exact`
    # The `root:` in those methods is used to resolve relative paths
    #
    # When used with {PathList#only}, it will also allow all containing directories (with a lower priority).
    class ExactPath
      # @api private
      # @param pattern [String]
      # @param polarity [:ignore, :allow]
      # @param root [String]
      def initialize(pattern, polarity, root)
        @path = CanonicalPath.full_path_from(pattern, root)
        @polarity = polarity
      end

      # @api private
      # @return [PathList::Matcher]
      def matcher
        Matcher::ExactString.build([@path], @polarity)
      end

      # @api private
      # @return [PathList::Matcher]
      def implicit_matcher
        @path_re = TokenRegexp::Path.new_from_path(@path)
        parent_matcher = build_parent_matcher

        Matcher::Any.build([parent_matcher, build_child_matcher])
      end

      private

      def build_parent_matcher
        ancestors = @path_re.ancestors

        exact, regexp = ancestors.partition(&:exact_path?)
        exact = Matcher::ExactString.build(exact.map(&:to_s), :allow)
        regexp = Matcher::PathRegexp.build(regexp.map(&:parts), :allow)

        Matcher::MatchIfDir.build(Matcher::Any.build([exact, regexp]))
      end

      def build_child_matcher
        @child_re = @path_re.dup
        @child_re.replace_end(:dir)

        Matcher::PathRegexp.build([@child_re.compress.parts], :allow)
      end
    end
  end
end
