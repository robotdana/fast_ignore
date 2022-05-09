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
      if gitignore
        @gitignore_rule_group = ::FastIgnore::GitignoreRuleGroup.new(root)
        @array << @gitignore_rule_group
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

    def add_gitignore(dir)
      @gitignore_rule_group.add_gitignore(dir)
    end
  end
end
