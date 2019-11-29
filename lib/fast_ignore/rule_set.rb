# frozen_string_literal: true

require_relative 'rule_parser'

class FastIgnore
  class RuleSet # rubocop:disable Metrics/ClassLength
    def initialize(only_or_ignore = :ignore, expand_path: false, root: ::Dir.pwd, project_root: root)
      @rules = []
      @root = root
      @project_root = project_root
      @expand_path = expand_path
      @only_or_ignore = only_or_ignore
    end

    def add_rules(rules, root: @root, expand_path: @expand_path)
      Array(rules).each do |rule_string|
        rule_string.each_line do |rule_line|
          rule = ::FastIgnore::RuleParser.new_rule(rule_line, root: root, expand_path: expand_path)
          @rules << rule if rule
        end
      end

      clear_cache
    end

    def add_files(files)
      Array(files).each do |filename|
        filename = ::File.expand_path(filename)
        root = ::File.dirname(filename)
        ::IO.foreach(filename) do |rule_string|
          rule = ::FastIgnore::RuleParser.new_rule(rule_string, root: root)
          @rules << rule if rule
        end
      end

      clear_cache
    end

    def globbable?
      return @globbable if defined?(@globbable)

      @globbable = @only_or_ignore == :only && !@rules.empty? && @rules.all?(&:globbable?)
    end

    def glob(&block)
      if block_given?
        ::Dir.glob(@rules.flat_map(&:glob_pattern), ::FastIgnore::Rule::FNMATCH_OPTIONS, &block)
      else
        ::Dir.glob(@rules.flat_map(&:glob_pattern), ::FastIgnore::Rule::FNMATCH_OPTIONS)
      end
    end

    def allowed_if_matched(path, dir = nil) # rubocop:disable Metrics/MethodLength
      @last_matching_rule ||= {}
      @last_matching_rule.fetch(path) do
        dir = ::File.directory?(path) if dir.nil?
        (dir ? @rules : non_dir_only_rules).reverse_each do |rule|
          if rule.match?(path)
            return @last_matching_rule[path] = if only?
                     !rule.negation?
                   else
                     rule.negation?
            end
          end
        end

        @last_matching_rule = nil
      end
    end

    def allowed_unrecursive?(path, dir = ::File.directory?(path))
      return true if empty?

      me = allowed_if_matched(path, dir)
      if me.nil?
        ignore?
      else
        me
      end
    end

    def allowed_recursive?(path, dir = nil) # rubocop:disable Metrics/MethodLength
      return true if empty?

      @allowed_recursive ||= {}
      @allowed_recursive.fetch(path) do
        dir = ::File.directory?(path) if dir.nil?
        ancestor = allowed_ancestors?(path)
        me = allowed_if_matched(path, dir)

        @allowed_recursive[path] = if ancestor.nil? && me.nil?
          ignore?
        elsif ancestor.nil?
          me
        elsif me.nil?
          ancestor
        else
          me && ancestor
        end
      end
    end

    def allowed_ancestors?(path) # rubocop:disable Metrics/MethodLength
      return nil if path == @project_root

      @allowed_ancestors ||= {}
      @allowed_ancestors.fetch(path) do
        path = ::File.dirname(path)
        ancestor = allowed_ancestors?(path)
        me = allowed_if_matched(path, true)

        @allowed_ancestors[path] = if me.nil? && ancestor.nil?
          nil
        elsif ancestor.nil?
          me
        elsif me.nil?
          ancestor
        else
          me && ancestor
        end
      end
    end

    def empty?
      return @empty if defined?(@empty)

      @empty = @rules.empty?
    end

    private

    def ignore?
      @only_or_ignore == :ignore
    end

    def only?
      @only_or_ignore == :only
    end

    def non_dir_only_rules
      @non_dir_only_rules ||= @rules.reject(&:dir_only?)
    end

    def clear_cache
      remove_instance_variable(:@non_dir_only_rules) if defined?(@non_dir_only_rules)
      remove_instance_variable(:@allowed_ancestors) if defined?(@allowed_ancestors)
      remove_instance_variable(:@allowed_recursive) if defined?(@allowed_recursive)
      remove_instance_variable(:@last_matching_rule) if defined?(@last_matching_rule)
      remove_instance_variable(:@globbable) if defined?(@globbable)
      remove_instance_variable(:@empty) if defined?(@empty)
    end
  end
end
