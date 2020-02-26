# frozen_string_literal: true

require_relative 'rule_parser'

class FastIgnore
  class RuleSet
    attr_reader :rules

    def initialize(project_root: Dir.pwd, allow: false)
      @rules = []
      @non_dir_only_rules = []
      @project_root = project_root

      @any_not_anchored = false
      @allow = allow
      @default = true unless allow
    end

    def allowed_recursive?(path, dir)
      @allowed_recursive ||= { @project_root => true }
      @allowed_recursive.fetch(path) do
        @allowed_recursive[path] =
          allowed_recursive?(::File.dirname(path), true) && allowed_unrecursive?(path, dir)
      end
    end

    def allowed_unrecursive?(path, dir)
      (dir ? @rules : @non_dir_only_rules).reverse_each do |rule|
        # 14 = Rule::FNMATCH_OPTIONS
        return rule.negation? if ::File.fnmatch?(rule.rule, path, 14)
      end

      (not @allow) || (@any_not_anchored if dir)
    end

    def append_rules(anchored, rules)
      rules.each do |rule|
        @rules << rule
        @non_dir_only_rules << rule unless rule.dir_only?
        @any_not_anchored ||= !anchored
      end
    end

    def length
      @rules.length
    end

    def empty?
      @rules.empty?
    end
  end
end
