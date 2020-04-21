# frozen_string_literal: true

class FastIgnore
  class RuleSet
    def initialize(rules, allow)
      @dir_rules = rules.reject(&:file_only?).freeze
      @file_rules = rules.reject(&:dir_only?).freeze
      @any_not_anchored = rules.any?(&:unanchored?)
      @has_shebang_rules = rules.any?(&:shebang)
      @allowed_recursive = { '.' => true }
      @allow = allow

      freeze
    end

    def freeze
      @dir_rules.freeze
      @file_rules.freeze

      super
    end

    def allowed_recursive?(path, dir, filename)
      @allowed_recursive.fetch(path) do
        @allowed_recursive[path] =
          allowed_recursive?(::File.dirname(path), true, nil) && allowed_unrecursive?(path, dir, filename)
      end
    end

    def allowed_unrecursive?(path, dir, filename)
      (dir ? @dir_rules : @file_rules).reverse_each do |rule|
        return rule.negation? if rule.match?(path, filename)
      end

      (not @allow) || (dir && @any_not_anchored)
    end

    def weight
      @dir_rules.length + (@has_shebang_rules ? 10 : 0)
    end

    def empty?
      @dir_rules.empty? && @file_rules.empty?
    end
  end
end
