# frozen_string_literal: true

class FastIgnore
  class RuleSet
    attr_reader :rules
    attr_reader :allow
    alias_method :allow?, :allow
    attr_reader :has_shebang_rules

    def initialize(allow: false)
      @dir_rules = []
      @file_rules = []
      @allowed_recursive = { '.' => true }
      @any_not_anchored = false
      @allow = allow
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
        # 14 = Rule::FNMATCH_OPTIONS

        return rule.negation? if rule.match?(path, filename)
      end

      (not @allow) || (@any_not_anchored if dir)
    end

    def append_rules(anchored, rules)
      rules.each do |rule|
        (@dir_rules << rule) unless rule.file_only?
        (@file_rules << rule) unless rule.dir_only?
        @any_not_anchored ||= !anchored
        @has_shebang_rules ||= rule.shebang
      end
    end

    def weight
      @dir_rules.length + (@has_shebang_rules ? 10 : 0)
    end

    def empty?
      @dir_rules.empty? && @file_rules.empty?
    end
  end
end
