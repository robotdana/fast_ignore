# frozen_string_literal: true

class PathList
  module Builders
    module Shebang
      def self.build(shebang, allow, _root)
        shebang.strip!
        pattern = /\A#!.*\b#{::Regexp.escape(shebang)}\b/i
        rule = Matchers::ShebangRegexp.new(pattern, allow)
        return rule unless allow

        # also allow all directories in case they include a file with the matching shebang file
        [Matchers::AllowAnyParent, rule]
      end
    end
  end
end
