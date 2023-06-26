# frozen_string_literal: true

class PathList
  module Builders
    module Shebang
      def self.build(shebang, allow, root) # rubocop:disable Metrics/MethodLength
        shebang = shebang.delete_prefix('#!').strip

        pattern = RegexpBuilder.new
        pattern.append_part :start_anchor
        pattern.append_string '#!'
        pattern.append_part :any
        # we only want word boundary anchors if we are going from word characters to non-word
        pattern.append_part :word_boundary if shebang.match?(/\A\w/)
        pattern.append_string shebang
        pattern.append_part :word_boundary if shebang.match?(/\w\z/)

        path_matcher_tail = { dir: { any_dir: { any_non_dot_non_dir: { end_anchor: nil } } } }
        path_matcher = RegexpBuilder.new_from_path(PathExpander.expand_path_pwd(root), path_matcher_tail)
        Matchers::MatchUnlessDir.build(
          Matchers::PathRegexpWrapper.build(
            path_matcher,
            Matchers::ShebangRegexp.build(pattern, allow)
          )
        )
      end

      # also allow all directories in case they include a file with the matching shebang file
      def self.build_implicit(_shebang, allow, root) # rubocop:disable Metrics/MethodLength
        if allow
          if root
            Matchers::MatchIfDir.build(
              Matchers::Any.build([
                Matchers::PathRegexp.build(
                  RegexpBuilder.new_from_path(root, { dir: { any_non_dir: nil } }).ancestors,
                  allow
                ),
                Matchers::PathRegexp.build(RegexpBuilder.new_from_path(root, { dir: nil }), allow)
              ])
            )
          else
            Matchers::AllowAnyDir
          end
        else
          Matchers::Blank
        end
      end
    end
  end
end
