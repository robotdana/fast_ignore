# frozen_string_literal: true

class PathList
  module Builders
    module Shebang
      def self.build(shebang, allow, root) # rubocop:disable Metrics/MethodLength
        shebang = shebang.delete_prefix('#!').strip
        # we only want word boundary anchors if we are going from word characters to non-word
        boundary_left = '\\b' if shebang.match?(/\A\w/)
        boundary_right = '\\b' if shebang.match?(/\w\z/)

        pattern = RegexpBuilder.new([
          :start_anchor, '#!', :any,
          "#{boundary_left}#{::Regexp.escape(shebang)}#{boundary_right}"
        ])

        Matchers::MatchUnlessDir.build(
          Matchers::PathRegexpWrapper.build(
            RegexpBuilder.new_from_path(PathExpander.expand_path_pwd(root), [:dir, :any_dir, '[^\.\/]*', :end_anchor]),
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
                Matchers::PathRegexp.build(RegexpBuilder.new_from_path(root, [:dir, :any_non_dir]).ancestors, allow),
                Matchers::PathRegexp.build(RegexpBuilder.new_from_path(root, [:dir]), allow)
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
