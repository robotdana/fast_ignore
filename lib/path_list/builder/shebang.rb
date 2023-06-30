# frozen_string_literal: true

class PathList
  class Builder
    class Shebang < Builder
      def initialize(rule, polarity, root)
        super

        @root_re = PathRegexp.new_from_path(root, [])
      end

      def build # rubocop:disable Metrics/MethodLength
        shebang = @rule.delete_prefix('#!').strip

        pattern = TokenRegexp.new([:start_anchor, '#!', :any])
        # we only want word boundary anchors if we are going from word characters to non-word
        pattern.append_part :word_boundary if shebang.match?(/\A\w/)
        pattern.append_string shebang
        pattern.append_part :word_boundary if shebang.match?(/\w\z/)

        Matchers::MatchUnlessDir.build(
          Matchers::PathRegexpWrapper.build(
            [@root_re.dup.concat([:dir, :any_dir, :any_non_dot_non_dir, :end_anchor]).parts], # rubocop:disable Style/ConcatArrayLiterals
            Matchers::ShebangRegexp.new([pattern.parts], @polarity)
          )
        )
      end

      # also allow all directories in case they include a file with the matching shebang file
      def build_implicit
        return Matchers::AllowAnyDir unless @root

        Matchers::MatchIfDir.build(build_parent_matcher)
      end

      private

      def build_parent_matcher
        ancestors = @root_re.dup.concat([:dir, :any_dir]).ancestors # rubocop:disable Style/ConcatArrayLiterals

        exact, regexp = ancestors.partition(&:exact_path?)
        exact = Matchers::ExactString.build(exact.map(&:to_s), :allow)
        regexp = Matchers::PathRegexp.build(regexp.map(&:parts), :allow)

        Matchers::MatchIfDir.build(Matchers::Any.build([exact, regexp]))
      end
    end
  end
end
