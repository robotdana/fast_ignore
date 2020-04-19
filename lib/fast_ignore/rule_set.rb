# frozen_string_literal: true

class FastIgnore
  class RuleSet
    attr_reader :rules
    attr_reader :allow
    alias_method :allow?, :allow

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

    def allowed_recursive?(path, dir)
      @allowed_recursive.fetch(path) do
        @allowed_recursive[path] =
          allowed_recursive?(::File.dirname(path), true) && allowed_unrecursive?(path, dir)
      end
    end

    def allowed_unrecursive?(path, dir)
      (dir ? @dir_rules : @file_rules).reverse_each do |rule|
        # 14 = Rule::FNMATCH_OPTIONS
        return rule.negation? if ::File.fnmatch?(rule.rule, path, 14)
      end

      (not @allow) || (@any_not_anchored if dir)
    end

    def append_rules(anchored, rules)
      rules.each do |rule|
        @dir_rules << rule
        @file_rules << rule unless rule.dir_only?
        @any_not_anchored ||= !anchored
      end
    end

    def length
      @dir_rules.length
    end

    def empty?
      @dir_rules.empty?
    end
  end
end
