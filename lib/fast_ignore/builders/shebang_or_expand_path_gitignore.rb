# frozen_string_literal: true

class FastIgnore
  module Builders
    module ShebangOrExpandPathGitignore
      def self.build(rule, allow, root)
        if rule.delete_prefix!('#!:')
          ::FastIgnore::Builders::Shebang.build(rule, allow, root)
        else
          ::FastIgnore::Builders::ExpandPathGitignore.build(rule, allow, root)
        end
      end
    end
  end
end
