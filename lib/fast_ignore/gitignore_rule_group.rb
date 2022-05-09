# frozen-string-literal: true

require 'set'

class FastIgnore
  class GitignoreRuleGroup < ::FastIgnore::RuleGroup
    def initialize(root)
      @loaded_paths = Set[]

      super([
        ::FastIgnore::Patterns.new('.git', root: '/'),
        ::FastIgnore::Patterns.new(from_file: ::FastIgnore::GlobalGitignore.path(root: root), root: root),
        ::FastIgnore::Patterns.new(from_file: "#{root}.git/info/exclude", root: root)
      ], false)
      add_gitignore(root)
    end

    def build
      @matchers = @patterns.flat_map { |x| x.build_matchers(allow: @allow) }.compact

      freeze
    end

    def append(new_pattern)
      @patterns << new_pattern

      return unless defined?(@matchers)

      new_matchers = new_pattern.build_matchers(allow: @allow)
      return if !new_matchers || new_matchers.empty?

      @matchers.concat(new_matchers)
    end

    def empty?
      false # if this gets removed then even if it's blank we can't add with GitignoreCollectingFileSystem
    end

    def add_gitignore(dir)
      return if @loaded_paths.include?(dir)

      @loaded_paths << dir
      append(::FastIgnore::Patterns.new(from_file: "#{dir}.gitignore", root: dir))
    end
  end
end
