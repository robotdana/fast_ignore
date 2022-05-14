# frozen_string_literal: true

class FastIgnore
  module RuleSetBuilder
    def self.build( # rubocop:disable Metrics/ParameterLists, Metrics/MethodLength
      root:,
      ignore_rules: nil,
      ignore_files: nil,
      gitignore: true,
      include_rules: nil,
      include_files: nil,
      argv_rules: nil
    )
      path_list = ::FastIgnore::PathList

      Array(ignore_files).each do |f|
        path = PathExpander.expand_path(f, root)
        path_list = path_list.ignore(from_file: path)
      end
      Array(include_files).each do |f|
        path = PathExpander.expand_path(f, root)
        path_list = path_list.only(from_file: path)
      end

      path_list = path_list.gitignore(root: root) if gitignore

      path_list.ignore(ignore_rules, root: root)
        .only(include_rules, root: root)
        .only(argv_rules, root: root, format: :expand_path)
        .only(root, root: '/').send(:rule_set)
    end
  end
end
