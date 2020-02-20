# frozen_string_literal: true

require_relative 'rule_parser'

class FastIgnore
  class RuleSet
    attr_reader :rules

    def initialize(project_root: Dir.pwd, allow: false)
      @rules = []
      @non_dir_only_rules = []
      @project_root = project_root
      @allowed_recursive = { @project_root => true }
      @any_not_anchored = false
      @empty = true
      @allow = allow
    end

    def allowed_recursive?(path, dir)
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

      default?(dir)
    end

    def parse_rules(rule_line, root: @root, expand_path: false)
      ::FastIgnore::RuleParser.new_rule(rule_line, rule_set: self, allow: @allow, root: root, expand_path: expand_path)
    end

    def append_rules(anchored, rules)
      rules.each do |rule|
        @empty = false
        @rules << rule
        @non_dir_only_rules << rule unless rule.dir_only?
        @any_not_anchored ||= !anchored
      end
    end

    def clear_cache
      @allowed_recursive = { @project_root => true }
    end

    private

    def default?(dir)
      return true unless @allow
      return true if @empty
      return false unless dir
      return true if @any_not_anchored

      false
    end
  end
end
