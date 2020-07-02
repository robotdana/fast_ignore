# frozen_string_literal: true

class FastIgnore
  class RuleSets
    # :nocov:
    using ::FastIgnore::Backports::DeletePrefixSuffix if defined?(::FastIgnore::Backports::DeletePrefixSuffix)
    # :nocov:

    def initialize( # rubocop:disable Metrics/ParameterLists
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
      append_set_from_array(ignore_rules)
      append_set_from_array(include_rules, allow: true)
      append_set_from_array(argv_rules, allow: true, expand_path_with: @project_root)
      append_sets_from_files(ignore_files)
      append_sets_from_files(include_files, allow: true)
      @array.sort_by!(&:weight)
      @array.freeze if @gitignore_rule_set
    end

    def allowed_recursive?(relative_path, full_path, filename, content)
      @array.all? { |r| r.allowed_recursive?(relative_path, false, full_path, filename, content) }
    end

    def allowed_unrecursive?(relative_path, dir, full_path, filename)
      @array.all? { |r| r.allowed_unrecursive?(relative_path, dir, full_path, filename, nil) }
    end

    def append_subdir_gitignore(relative_path:, check_exists: true)
      new_gitignore = build_set_from_file(relative_path, gitignore: true, check_exists: check_exists)
      return if !new_gitignore || new_gitignore.empty?

      if @gitignore_rule_set
        @gitignore_rule_set << new_gitignore
      else
        @array << new_gitignore
        @gitignore_rule_set = new_gitignore
        @array.sort_by!(&:weight) && @array.freeze
      end
      new_gitignore
    end

    private

    def append_and_return_if_present(value)
      return unless value && !value.empty?

      @array << value
      value
    end

    def append_root_gitignore(gitignore)
      return @gitignore_rule_set = nil unless gitignore

      append_set_from_array('.git')
      gi = ::FastIgnore::RuleSet.new([], false, true)
      gi << build_from_root_gitignore_file(::FastIgnore::GlobalGitignore.path(root: @project_root))
      gi << build_from_root_gitignore_file("#{@project_root}.git/info/exclude")
      gi << build_from_root_gitignore_file("#{@project_root}.gitignore")
      @gitignore_rule_set = append_and_return_if_present(gi)
    end

    def build_from_root_gitignore_file(path)
      return unless ::File.exist?(path)

      build_rule_set(::File.readlines(path), false, gitignore: true)
    end

    def build_rule_set(rules, allow, expand_path_with: nil, file_root: nil, gitignore: false)
      rules = rules.flat_map do |rule|
        ::FastIgnore::RuleBuilder.build(rule, allow, expand_path_with, file_root)
      end

      ::FastIgnore::RuleSet.new(rules, allow, gitignore)
    end

    def build_set_from_file(filename, allow: false, gitignore: false, check_exists: false)
      filename = ::File.expand_path(filename, @project_root)
      return if check_exists && !::File.exist?(filename)
      raise ::FastIgnore::Error, "#{filename} is not within #{@project_root}" unless filename.start_with?(@project_root)

      file_root = ::FastIgnore::FileRoot.build(filename, @project_root)
      build_rule_set(::File.readlines(filename), allow, file_root: file_root, gitignore: gitignore)
    end

    def append_sets_from_files(files, allow: false)
      Array(files).each do |file|
        append_and_return_if_present(build_set_from_file(file, allow: allow))
      end
    end

    def append_set_from_array(rules, allow: false, expand_path_with: nil)
      return unless rules

      rules = Array(rules).flat_map { |string| string.to_s.lines }
      return if rules.empty?

      append_and_return_if_present(build_rule_set(rules, allow, expand_path_with: expand_path_with))
    end
  end
end
