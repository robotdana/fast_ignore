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
      rule_set = ::FastIgnore::RuleSet

      Array(ignore_files).each do |f|
        path = PathExpander.expand_path(f, root)
        rule_set = rule_set.new(
          ::FastIgnore::RuleGroup.new(::FastIgnore::Patterns.new(from_file: path), false)
        )
      end
      Array(include_files).each do |f|
        path = PathExpander.expand_path(f, root)
        rule_set = rule_set.new(
          ::FastIgnore::RuleGroup.new(::FastIgnore::Patterns.new(from_file: path), true)
        )
      end

      if gitignore
        rule_set = rule_set.new(
          ::FastIgnore::AppendableRuleGroup.new(root, false)
          .append(
            ::FastIgnore::Patterns.new(from_file: ::FastIgnore::GlobalGitignore.path(root: root), root: root)
          ).append(
            ::FastIgnore::Patterns.new(from_file: "#{root}.git/info/exclude", root: root)
          ).append(
            ::FastIgnore::Patterns.new(from_file: "#{root}.gitignore", root: root)
          ),
          label: :gitignore
        ).new(
          ::FastIgnore::RuleGroup.new(::FastIgnore::Patterns.new('.git', root: '/'), false),
          walker: ::FastIgnore::Walkers::GitignoreCollectingFileSystem
        )
      end

      rule_set.new(
        ::FastIgnore::RuleGroup.new(::FastIgnore::Patterns.new(ignore_rules, root: root), false)
      ).new(
        ::FastIgnore::RuleGroup.new(::FastIgnore::Patterns.new(include_rules, root: root), true)
      ).new(
        ::FastIgnore::RuleGroup.new(
          ::FastIgnore::Patterns.new(argv_rules, root: root, format: :expand_path),
          true
        )
      )
    end
  end
end
