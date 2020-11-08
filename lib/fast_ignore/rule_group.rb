# frozen_string_literal: true

class FastIgnore
  class RuleGroup
    def initialize(rule_sets, allow)
      @rule_sets = Array(rule_sets).compact
      @allow = allow
      @allowed_recursive = { '/' => true }
    end

    def empty?
      @rule_sets.empty? || @rule_sets.all?(&:empty?)
    end

    def weight
      @rule_sets.sum(&:weight)
    end

    def freeze
      @rule_sets.freeze

      super
    end

    def <<(rule_set)
      (@rule_sets += rule_set) unless !rule_set || rule_set.empty?
    end

    def allowed_recursive?(root_candidate)
      @allowed_recursive.fetch(root_candidate.full_path) do
        @allowed_recursive[root_candidate.full_path] =
          allowed_recursive?(root_candidate.parent) &&
          allowed_unrecursive?(root_candidate)
      end
    end

    def allowed_unrecursive?(root_candidate)
      @rule_sets.reverse_each do |rule_set|
        val = rule_set.match?(root_candidate)
        return val == :allow if val
      end

      not @allow
    end
  end
end
