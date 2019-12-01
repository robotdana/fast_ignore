# frozen_string_literal: true

require_relative 'rule_parser'

class FastIgnore
  class RuleSet
    attr_reader :rules

    def initialize(expand_path: false, root: ::Dir.pwd, allow: false, project_root: root)
      @rules = []
      @non_dir_only_rules = []
      @root = root
      @allowed_unrecursive = {}
      @allowed_recursive = {}
      @project_root = project_root
      @expand_path = expand_path
      @allow = allow
      @any_not_anchored = false
      @empty = true
    end

    def add_rules(rules, root: @root, expand_path: @expand_path)
      rules.each do |rule_string|
        rule_string.each_line do |rule_line|
          append_rules(
            *::FastIgnore::RuleParser.new_rule(rule_line, allow: @allow, root: root, expand_path: expand_path)
          )
        end
      end

      clear_cache
    end

    def add_files(files)
      files.each do |filename|
        filename = ::File.expand_path(filename)
        root = ::File.dirname(filename)
        ::IO.foreach(filename) do |rule_string|
          append_rules(*::FastIgnore::RuleParser.new_rule(rule_string, allow: @allow, root: root))
        end
      end

      clear_cache
    end

    def allowed_unrecursive?(path, dir)
      @allowed_unrecursive.fetch(path) do
        (dir ? @rules : @non_dir_only_rules).reverse_each do |rule|
          return @allowed_unrecursive[path] = rule.negation? if rule.match?(path)
        end

        @allowed_unrecursive[path] = default?(dir)
      end
    end

    def default?(dir)
      return true unless @allow
      return true if @empty
      return false unless dir
      return true if @any_not_anchored

      false
    end

    def allowed_recursive?(path, dir)
      return true if path == @project_root

      @allowed_recursive.fetch(path) do
        @allowed_recursive[path] =
          allowed_recursive?(path, true) && allowed_unrecusrive?(path, dir)
      end
    end

    private

    def append_rules(anchored, rules)
      rules.each do |rule|
        @empty = false
        @rules << rule
        @non_dir_only_rules << rule unless rule.dir_only?
        @any_not_anchored ||= !anchored
      end
    end

    attr_reader :non_dir_only_rules

    def clear_cache
      @allowed_unrecursive = {}
      @allowed_recursive = {}
    end
  end
end
