# frozen_string_literal: true

require_relative 'rule_parser'

class FastIgnore
  class RuleSet
    attr_reader :rules

    def initialize(project_root: Dir.pwd, allow: false)
      @rules = []
      @non_dir_only_rules = []
      @allowed_unrecursive = {}
      @allowed_recursive = {}
      @project_root = project_root
      @any_not_anchored = false
      @empty = true
      @allow = allow
    end

    def allowed_unrecursive?(path, dir)
      @allowed_unrecursive.fetch(path) do
        (dir ? @rules : @non_dir_only_rules).reverse_each do |rule|
          # 14 = Rule::FNMATCH_OPTIONS
          return @allowed_unrecursive[path] = rule.negation? if ::File.fnmatch?(rule.rule, path, 14)
        end

        @allowed_unrecursive[path] = default?(dir)
      end
    end

    def allowed_recursive?(path, dir)
      return true if path == @project_root

      @allowed_recursive.fetch(path) do
        @allowed_recursive[path] =
          allowed_recursive?(path, true) && allowed_unrecusrive?(path, dir)
      end
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
      @allowed_unrecursive = {}
      @allowed_recursive = {}
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
