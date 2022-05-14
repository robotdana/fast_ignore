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
        rule_set = rule_set.new(::FastIgnore::Patterns.new(from_file: path))
      end
      Array(include_files).each do |f|
        path = PathExpander.expand_path(f, root)
        rule_set = rule_set.new(::FastIgnore::Patterns.new(from_file: path, allow: true))
      end

      if gitignore
        rule_set = rule_set.new(
          ::FastIgnore::AppendablePatterns.new(root: root)
            .append(from_file: ::FastIgnore::GlobalGitignore.path(root: root), root: root)
            .append(from_file: './.git/info/exclude', root: root)
            .append(from_file: './.gitignore', root: root),
          label: :gitignore
        ).new(
          ::FastIgnore::Patterns.new('.git', root: '/'),
          walker: ::FastIgnore::Walkers::GitignoreCollectingFileSystem
        )
      end

      rule_set.new(
        ::FastIgnore::Patterns.new(ignore_rules, root: root)
      ).new(
        ::FastIgnore::Patterns.new(include_rules, root: root, allow: true)
      ).new(
        ::FastIgnore::Patterns.new(argv_rules, root: root, format: :expand_path, allow: true)
      ).new(
        ::FastIgnore::Patterns.new(root, root: '/', allow: true)
      )
    end
  end
end
