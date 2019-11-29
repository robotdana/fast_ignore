# frozen_string_literal: true

class FastIgnore
  class RuleParser
    # rule or nil
    def rule(rule, root:, expand_path: false)
      rule = strip(rule)
      rule, dir_only = extract_dir_only(rule)
      rule = expand_path(rule) if expand_path
      return if skip?(rule)

      rule, negation = extract_negation(rule)

      rule = "#{root}#{prefix(rule)}#{rule}"

      ::FastIgnore::Rule.new(rule, dir_only: dir_only, negation: negation)
    end

    def strip(rule)
      rule = rule.chomp
      rule = rule.rstrip unless rule.end_with?('\\ ')
      rule
    end
  end
end
