# frozen_string_literal: true

class PathList
  module Builders
    module Shebang
      def self.build(shebang, allow, _root)
        shebang = shebang.delete_prefix('#!').strip
        # we only want word boundary anchors if we are going from word characters to non-word
        boundary_left = '\\b' if shebang.match?(/\A\w/)
        boundary_right = '\\b' if shebang.match?(/\w\z/)
        pattern = /\A#!.*#{boundary_left}#{::Regexp.escape(shebang)}#{boundary_right}/i

        rule = Matchers::ShebangRegexp.new(pattern, allow)
        return rule unless allow

        # also allow all directories in case they include a file with the matching shebang file
        [Matchers::AllowAnyParent, rule]
      end
    end
  end
end
