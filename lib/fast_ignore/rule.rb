# frozen_string_literal: true

class FastIgnore
  module Rule
    def self.new(rule, negation, anchored, dir_only)
      if negation
        ::FastIgnore::AllowRule.new(rule, anchored, dir_only)
      else
        ::FastIgnore::IgnoreRule.new(rule, anchored, dir_only)
      end
    end
  end
end
