# frozen_string_literal: true

class FastIgnore
  module RuleSetBuilder
    def self.build( # rubocop:disable Metrics/ParameterLists, Metrics/AbcSize, Metrics/MethodLength
      root:,
      ignore_rules: nil,
      ignore_files: nil,
      gitignore: true,
      include_rules: nil,
      include_files: nil,
      argv_rules: nil
    )
      rule_set = nil

      if gitignore
        rule_set = ::FastIgnore::RuleSet.new(
          ::FastIgnore::RuleGroup.new(::FastIgnore::Patterns.new('.git', root: '/'), false),
          walker: ::FastIgnore::Walkers::GitignoreCollectingFileSystem
        )

        gitignore_rule_group = ::FastIgnore::AppendableRuleGroup.new(root, false)
        rule_set = ::FastIgnore::RuleSet.new(
          gitignore_rule_group,
          label: :gitignore,
          from: rule_set
        )
        gitignore_rule_group.append(
          ::FastIgnore::Patterns.new(from_file: ::FastIgnore::GlobalGitignore.path(root: root), root: root)
        )
        gitignore_rule_group.append(
          ::FastIgnore::Patterns.new(from_file: "#{root}.git/info/exclude", root: root)
        )
        gitignore_rule_group.append(
          ::FastIgnore::Patterns.new(from_file: "#{root}.gitignore", root: root)
        )
      end
      rule_set = ::FastIgnore::RuleSet.new(
        ::FastIgnore::RuleGroup.new(::FastIgnore::Patterns.new(ignore_rules, root: root), false),
        from: rule_set
      )
      rule_set = ::FastIgnore::RuleSet.new(
        ::FastIgnore::RuleGroup.new(::FastIgnore::Patterns.new(include_rules, root: root), true),
        from: rule_set
      )
      rule_set = ::FastIgnore::RuleSet.new(
        ::FastIgnore::RuleGroup.new(
          ::FastIgnore::Patterns.new(argv_rules, root: root, format: :expand_path),
          true
        ),
        from: rule_set
      )
      Array(ignore_files).each do |f|
        path = PathExpander.expand_path(f, root)
        rule_set = ::FastIgnore::RuleSet.new(
          ::FastIgnore::RuleGroup.new(::FastIgnore::Patterns.new(from_file: path), false),
          from: rule_set
        )
      end
      Array(include_files).each do |f|
        path = PathExpander.expand_path(f, root)
        rule_set = ::FastIgnore::RuleSet.new(
          ::FastIgnore::RuleGroup.new(::FastIgnore::Patterns.new(from_file: path), true),
          from: rule_set
        )
      end

      rule_set
    end
  end
end
