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
      @appendable_groups = {}
      if gitignore
        @array << ::FastIgnore::RuleGroup.new(::FastIgnore::Patterns.new('.git', root: '/'), false)

        gitignore_rule_group = ::FastIgnore::AppendableRuleGroup.new(false)
        gitignore_rule_group.append(
          ::FastIgnore::Patterns.new(from_file: ::FastIgnore::GlobalGitignore.path(root: root), root: root)
        )
        gitignore_rule_group.append(
          ::FastIgnore::Patterns.new(from_file: "#{root}.git/info/exclude", root: root)
        )
        gitignore_rule_group.append(
          ::FastIgnore::Patterns.new(from_file: "#{root}.gitignore", root: root)
        )
        @array << gitignore_rule_group
        @appendable_groups[:gitignore] = gitignore_rule_group
      end
      @array << ::FastIgnore::RuleGroup.new(::FastIgnore::Patterns.new(ignore_rules, root: root), false)
      @array << ::FastIgnore::RuleGroup.new(::FastIgnore::Patterns.new(include_rules, root: root), true)
      @array << ::FastIgnore::RuleGroup.new(
        ::FastIgnore::Patterns.new(argv_rules, root: root, format: :expand_path),
        true
      )

      Array(ignore_files).each do |f|
        path = PathExpander.expand_path(f, root)
        @array << ::FastIgnore::RuleGroup.new(::FastIgnore::Patterns.new(from_file: path), false)
      end
      Array(include_files).each do |f|
        path = PathExpander.expand_path(f, root)
        @array << ::FastIgnore::RuleGroup.new(::FastIgnore::Patterns.new(from_file: path), true)
      end
    end

    def build
      @array.each(&:build)
      @array.reject!(&:empty?)
      @array.sort_by!(&:weight)
      @array.freeze

      freeze
    end

    def allowed_recursive?(candidate)
      @array.all? { |r| r.allowed_recursive?(candidate) }
    end

    def allowed_unrecursive?(candidate)
      @array.all? { |r| r.allowed_unrecursive?(candidate) }
    end

    def append(label, pattern)
      @appendable_groups[label].append(pattern)
    end
  end
end
