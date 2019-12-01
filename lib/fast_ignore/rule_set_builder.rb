# frozen_string_literal: true

require_relative 'rule_set'

class FastIgnore
  class RuleSetBuilder
    attr_reader :rules

    def initialize(root:, allow: false)
      @rule_set = RuleSet.new(project_root: root, allow: allow)
      @root = root
      @allow = allow
    end

    def add_rules(rules, expand_path: false)
      rules.each do |rule_string|
        rule_string.each_line do |rule_line|
          @rule_set.parse_rules(rule_line, root: @root, expand_path: expand_path)
        end
      end

      @rule_set.clear_cache
    end

    def add_files(files)
      files.each do |filename|
        filename = ::File.expand_path(filename)
        root = ::File.dirname(filename)
        ::IO.foreach(filename) do |rule_string|
          @rule_set.parse_rules(rule_string, root: root)
        end
      end

      @rule_set.clear_cache
    end

    def allowed_unrecursive?(path, dir)
      @rule_set.allowed_unrecursive?(path, dir)
    end

    def allowed_recursive?(path, dir)
      @rule_set.allowed_recursive?(path, dir)
    end
  end
end
