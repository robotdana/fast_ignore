# frozen_string_literal: true

class FastIgnore
  class RuleSet
    def initialize(rules, root)
      @dir_rules = rules.reject(&:file_only?)
      @file_rules = rules.reject(&:dir_only?)
      @has_shebang_rules = rules.any?(&:shebang?)
      @root = root

      freeze
    end

    def match?(root_candidate)
      relative_candidate = root_candidate.relative_to(@root)
      return false unless relative_candidate

      (relative_candidate.directory? ? @dir_rules : @file_rules).reverse_each do |rule|
        val = rule.match?(relative_candidate)
        return val if val
      end

      false
    end

    def empty?
      @dir_rules.empty? && @file_rules.empty?
    end

    def weight
      @dir_rules.length + (@has_shebang_rules ? 10 : 0)
    end
  end
end
