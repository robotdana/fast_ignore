# frozen_string_literal: true

class FastIgnore
  class RuleGroups
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

      append_root_gitignore(gitignore)
      build_and_append_rule_group(::FastIgnore::Patterns(ignore_rules, root: @project_root), include: false)
      build_and_append_rule_group(::FastIgnore::Patterns(include_rules, root: @project_root), include: true)
      build_and_append_rule_group(
        ::FastIgnore::Patterns(argv_rules, root: @project_root, format: :expand_path),
        include: true
      )

      Array(ignore_files).each do |f|
        path = PathExpander.expand_path(f, @project_root)
        build_and_append_rule_group(::FastIgnore::Patterns(from_file: path), include: false)
      end
      Array(include_files).each do |f|
        path = PathExpander.expand_path(f, @project_root)
        build_and_append_rule_group(::FastIgnore::Patterns(from_file: path), include: true)
      end

      @array.sort_by!(&:weight)
      @array.freeze
    end

    def allowed_recursive?(candidate)
      @array.all? { |r| r.allowed_recursive?(candidate) }
    end

    def allowed_unrecursive?(candidate)
      @array.all? { |r| r.allowed_unrecursive?(candidate) }
    end

    def append_subdir_gitignore(relative_path:, check_exists: true)
      path = PathExpander.expand_path(relative_path, @project_root)
      return if check_exists && !::File.exist?(path)

      new_gitignore = ::FastIgnore::Patterns(from_file: path).build_matchers
      return unless new_gitignore

      @gitignore_rule_group << new_gitignore
      @gitignore_rule_group
    end

    private

    def append_root_gitignore(gitignore)
      return @gitignore_rule_group = nil unless gitignore

      gi = ::FastIgnore::RuleGroup.new([], false)
      gi << ::FastIgnore::Patterns('.git', root: '/').build_matchers
      gi << ::FastIgnore::Patterns(
        from_file: ::FastIgnore::GlobalGitignore.path(root: @project_root), root: @project_root
      ).build_matchers
      gi << ::FastIgnore::Patterns(from_file: "#{@project_root}.git/info/exclude", root: @project_root).build_matchers
      gi << ::FastIgnore::Patterns(from_file: "#{@project_root}.gitignore", root: @project_root).build_matchers
      @array << @gitignore_rule_group = gi
    end

    def build_and_append_rule_group(pattern, include: false)
      matchers = pattern.build_matchers(include: include)
      return unless matchers

      @array << ::FastIgnore::RuleGroup.new(matchers, include).freeze
    end
  end
end
