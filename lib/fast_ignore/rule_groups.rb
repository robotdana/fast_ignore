# frozen_string_literal: true

class FastIgnore
  class RuleGroups
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
      @array.freeze if @gitignore_rule_group
    end

    def allowed_recursive?(candidate)
      @array.all? { |r| r.allowed_recursive?(candidate) }
    end

    def allowed_unrecursive?(candidate)
      @array.all? { |r| r.allowed_unrecursive?(candidate) }
    end

    def append_subdir_gitignore(relative_path:, check_exists: true)
      new_gitignore = build_set_from_file(relative_path, check_exists: check_exists)
      return if !new_gitignore || new_gitignore.empty? || new_gitignore.all?(&:empty?)

      @gitignore_rule_group << new_gitignore
      @gitignore_rule_group
    end

    private

    def append_and_return_if_present(value)
      return if !value || value.empty?

      @array << value
      value
    end

    def append_root_gitignore(gitignore)
      return @gitignore_rule_group = nil unless gitignore

      gi = ::FastIgnore::RuleGroup.new([], false)
      gi << build_rule_set([+'.git'], false, file_root: '/')
      gi << build_from_root_gitignore_file(::FastIgnore::GlobalGitignore.path(root: @project_root))
      gi << build_from_root_gitignore_file("#{@project_root}.git/info/exclude")
      gi << build_from_root_gitignore_file("#{@project_root}.gitignore")
      @array << @gitignore_rule_group = gi
    end

    def build_from_root_gitignore_file(path)
      return unless path && ::File.exist?(path)

      build_rule_set(::File.readlines(path), false)
    end

    def build_file_to_root_rule_set(file_root)
      path_parts = file_root.delete_prefix('/').split('/')
      re = Regexp.new("\\A(?:#{path_parts.map { |x| Regexp.escape(x) }.join('(?:/')}#{')?' * path_parts.length}\\z", 1)
      ::FastIgnore::RuleSet.new([::FastIgnore::Rule.new(re, true, true, true)], '/')
    end

    def build_rule_set(rules, allow, expand_path_with: nil, file_root: nil)
      rules = rules.flat_map do |rule|
        ::FastIgnore::RuleBuilder.build(rule, allow, expand_path_with)
      end

      return if rules.empty?

      set = [::FastIgnore::RuleSet.new(rules, file_root || @project_root)]

      (set << build_file_to_root_rule_set(file_root || @project_root)) if allow

      set
    end

    def build_rule_group(rule_sets, allow)
      return if !rule_sets || rule_sets.empty?

      ::FastIgnore::RuleGroup.new(rule_sets, allow).freeze
    end

    def build_set_from_file(filename, allow: false, check_exists: false)
      filename = PathExpander.expand_path(filename, @project_root)

      return if check_exists && !::File.exist?(filename)
      raise ::FastIgnore::Error, "#{filename} is not within #{@project_root}" unless filename.start_with?(@project_root)

      file_root = "#{::File.dirname(filename)}/"
      build_rule_set(::File.readlines(filename), allow, file_root: file_root)
    end

    def append_sets_from_files(files, allow: false)
      Array(files).each do |file|
        append_and_return_if_present(build_rule_group(build_set_from_file(file, allow: allow), allow))
      end
    end

    def append_set_from_array(rules, allow: false, expand_path_with: nil)
      return unless rules

      rules = Array(rules).flat_map { |string| string.to_s.lines }
      return if rules.empty?

      append_and_return_if_present(build_rule_group(
        build_rule_set(rules, allow, expand_path_with: expand_path_with), allow
      ))
    end
  end
end
