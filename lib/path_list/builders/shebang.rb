# frozen_string_literal: true

class PathList
  module Builders
    module Shebang
      def self.build(shebang, allow, _root)
        shebang = shebang.delete_prefix('#!').strip
        # we only want word boundary anchors if we are going from word characters to non-word
        boundary_left = '\\b' if shebang.match?(/\A\w/)
        boundary_right = '\\b' if shebang.match?(/\w\z/)

        pattern = RegexpBuilder.new([
          :start_anchor, '#!', :any,
          "#{boundary_left}#{::Regexp.escape(shebang)}#{boundary_right}"
        ])
        Matchers::MatchUnlessDir.build(Matchers::ShebangRegexp.build(pattern, allow))
      end

      # also allow all directories in case they include a file with the matching shebang file
      def self.build_implicit(_shebang, allow, _root)
        allow ? Matchers::AllowAnyDir : Matchers::Blank
      end
    end
  end
end
