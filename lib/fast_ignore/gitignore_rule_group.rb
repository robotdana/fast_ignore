# frozen-string-literal: true

require 'set'

class FastIgnore
  class GitignoreRuleGroup < ::FastIgnore::RuleGroup
    def initialize(root)
      @root = root
      @loaded_paths = Set[root]

      super([
        ::FastIgnore::Patterns.new('.git', root: '/'),
        ::FastIgnore::Patterns.new(from_file: ::FastIgnore::GlobalGitignore.path(root: root), root: root),
        ::FastIgnore::Patterns.new(from_file: "#{root}.git/info/exclude", root: root),
        ::FastIgnore::Patterns.new(from_file: "#{root}.gitignore", root: root)
      ], false)
    end

    def add_gitignore(dir)
      return if @loaded_paths.include?(dir)

      @loaded_paths << dir
      matcher = ::FastIgnore::Patterns.new(from_file: "#{dir}.gitignore").build_matchers(include: false)
      @matchers += matcher unless !matcher || matcher.empty?
    end

    def add_gitignore_to_root(path)
      add_gitignore(path) until @loaded_paths.include?(path = "#{::File.dirname(path)}/")
    end
  end
end
