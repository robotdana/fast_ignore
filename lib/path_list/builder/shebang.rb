# frozen_string_literal: true

class PathList
  class Builder
    class Shebang < Builder
      def initialize(rule, polarity, root)
        super

        @root_re = PathRegexp.new_from_path(root, [])
      end

      def build
        shebang = @rule.delete_prefix('#!').strip

        pattern = TokenRegexp.new([:start_anchor, '#!', :any])
        # we only want word boundary anchors if we are going from word characters to non-word
        pattern.append_part :word_boundary if shebang.match?(/\A\w/)
        pattern.append_string shebang
        pattern.append_part :word_boundary if shebang.match?(/\w\z/)

        Matcher::MatchUnlessDir.build(
          Matcher::PathRegexpWrapper.build(
            %r{\A#{Regexp.escape(@root.downcase)}/(?:.*/)?[^/\.]*\z},
            Matcher::ShebangRegexp.build([pattern.parts], @polarity)
          )
        )
      end

      # also allow all directories in case they include a file with the matching shebang file
      def build_implicit
        ancestors = @root_re.dup.concat([:dir, :any_dir]).ancestors # rubocop:disable Style/ConcatArrayLiterals

        exact, regexp = ancestors.partition(&:exact_path?)
        exact = Matcher::ExactString.build(exact.map(&:to_s), :allow)
        regexp = Matcher::PathRegexp.build(regexp.map(&:parts), :allow)

        Matcher::MatchIfDir.build(Matcher::Any.build([exact, regexp]))
      end
    end
  end
end
