# frozen_string_literal: true

class FastIgnore
  class RuleGroups
    # :nocov:
    using ::FastIgnore::Backports::DeletePrefixSuffix if defined?(::FastIgnore::Backports::DeletePrefixSuffix)
    # :nocov:

    def initialize( # rubocop:disable Metrics/ParameterLists, Metrics/AbcSize, Metrics/MethodLength
      root:,
      ignore_rules: nil,
      ignore_files: nil,
      gitignore: true,
      include_rules: nil,
      include_files: nil,
      argv_rules: nil
    )
      @array = []
      @project_root = root

      append_root_gitignore(gitignore, @project_root)
      build_and_append_rule_group(::FastIgnore::Patterns.new(ignore_rules, root: @project_root), include: false)
      build_and_append_rule_group(::FastIgnore::Patterns.new(include_rules, root: @project_root), include: true)
      build_and_append_rule_group(
        ::FastIgnore::Patterns.new(argv_rules, root: @project_root, format: :expand_path),
        include: true
      )

      Array(ignore_files).each do |f|
        path = ::File.expand_path(f, @project_root)
        build_and_append_rule_group(::FastIgnore::Patterns.new(from_file: path), include: false)
      end
      Array(include_files).each do |f|
        path = ::File.expand_path(f, @project_root)
        build_and_append_rule_group(::FastIgnore::Patterns.new(from_file: path), include: true)
      end
      @array.reject!(&:empty?)
      @array.sort_by!(&:weight)
      @array.freeze
    end

    def allowed_recursive?(candidate)
      @array.all? { |r| r.allowed_recursive?(candidate) }
    end

    def allowed_unrecursive?(candidate)
      @array.all? { |r| r.allowed_unrecursive?(candidate) }
    end

    def append_subdir_gitignore(full_path)
      @gitignore_rule_group << ::FastIgnore::Patterns.new(from_file: full_path)
    end

    private

    def append_root_gitignore(gitignore, root)
      return @gitignore_rule_group = nil unless gitignore

      gi = ::FastIgnore::RuleGroup.new([], false)
      gi << ::FastIgnore::Patterns.new('.git', root: '/')
      gi << ::FastIgnore::Patterns.new(from_file: ::FastIgnore::GlobalGitignore.path(root: root), root: root)
      gi << ::FastIgnore::Patterns.new(from_file: "#{root}.git/info/exclude", root: root)
      gi << ::FastIgnore::Patterns.new(from_file: "#{root}.gitignore", root: root)
      @array << @gitignore_rule_group = gi
    end

    def build_and_append_rule_group(pattern, include: false)
      @array << ::FastIgnore::RuleGroup.new(pattern, include).freeze
    end
  end
end
