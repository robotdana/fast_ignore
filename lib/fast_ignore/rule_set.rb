# frozen_string_literal: true

class FastIgnore
  class RuleSet
    attr_reader :rules
    attr_reader :allow
    alias_method :allow?, :allow

    def initialize(project_root: Dir.pwd, allow: false, and_no_ext: false)
      @dir_rules = []
      @file_rules = []
      @project_root = project_root
      @and_no_ext = and_no_ext

      @any_not_anchored = false
      @allow = allow
      @default = true unless allow
    end

    def allowed_recursive?(path, dir, basename)
      @allowed_recursive ||= { @project_root => true }
      @allowed_recursive.fetch(path) do
        @allowed_recursive[path] =
          allowed_recursive?(::File.dirname(path), true, nil) && allowed_unrecursive?(path, dir, basename)
      end
    end

    def allowed_unrecursive?(path, dir, basename)
      if @and_no_ext
        return true if dir
        return true unless basename&.include?('.')
      end

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
