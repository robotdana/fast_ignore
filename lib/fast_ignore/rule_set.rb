# frozen_string_literal: true

require_relative 'rule_parser'

class FastIgnore
  class RuleSet # rubocop:disable Metrics/ClassLength
    attr_reader :rules

    def initialize(expand_path: false, root: ::Dir.pwd, project_root: root)
      @rules = []
      @non_dir_only_rules = []
      @root = root
      @allowed_unrecursive = {}
      @allowed_recursive = {}
      @project_root = project_root
      @expand_path = expand_path
    end

    def add_rules(rules, root: @root, expand_path: @expand_path)
      Array(rules).each do |rule_string|
        rule_string.each_line do |rule_line|
          add_rule ::FastIgnore::RuleParser.new_rule(rule_line, root: root, expand_path: expand_path)
        end
      end

      clear_cache
    end

    def add_files(files)
      Array(files).each do |filename|
        filename = ::File.expand_path(filename)
        root = ::File.dirname(filename)
        ::IO.foreach(filename) do |rule_string|
          add_rule ::FastIgnore::RuleParser.new_rule(rule_string, root: root)
        end
      end

      clear_cache
    end

    def allowed_unrecursive?(path, dir) # rubocop:disable Metrics/MethodLength
      @allowed_unrecursive.fetch(path) do
        (dir ? @rules : @non_dir_only_rules).reverse_each do |rule|
          if rule.match?(path)
            return @allowed_unrecursive[path] = rule.negation?
          end
        end

        @allowed_unrecursive[path] = true
      end
    end

    def allowed_recursive?(path, dir) # rubocop:disable Metrics/MethodLength
      return true if path == @project_root

      @allowed_recursive.fetch(path) do
        @allowed_recursive[path] =
          allowed_recursive?(path, true) && allowed_unrecusrive?(path, dir)
      end
    end

    def empty?
      @rules.empty?
    end

    private

    def add_rule(rule)
      return unless rule

      @rules << rule
      @non_dir_only_rules << rule unless rule.dir_only?
    end

    def non_dir_only_rules
      @non_dir_only_rules # ||= @rules.reject(&:dir_only?)
    end

    def clear_cache
      @allowed_unrecursive = {}
      @allowed_recursive = {}
    end
  end
end
