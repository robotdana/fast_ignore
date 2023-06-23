# frozen_string_literal: true

class PathList
  module Matchers
    class CollectGitignore < Wrapper
      def self.build(re_builder, matcher = Mutable.new(Blank))
        rule = re_builder.to_regexp
        return Blank unless rule

        new(rule, matcher)
      end

      def initialize(collect_rule, matcher)
        @collect_rule = collect_rule
        @loaded = [] # not frozen
        @matcher = matcher
      end

      def squashable_with?(_)
        false
      end

      def weight
        @weight ||= (@matcher.weight * 0.2) + (@collect_rule.inspect.length / 4.0) + 2
      end

      def match(candidate)
        if candidate.directory? && @collect_rule.match?(candidate.full_path)
          append('./.gitignore',
                 root: candidate.full_path)
        end

        @matcher.match(candidate)
      end

      def append(from_file, root: nil)
        from_file = PathExpander.expand_path(from_file, root)
        return if @loaded.include?(from_file)

        @loaded << from_file

        patterns = Patterns.new(from_file: from_file, root: (root || PathExpander.expand_path_pwd('.')), allow: false,
                                format: Builders::Gitignore)
        _, new_matcher = patterns.build_matchers
        return if new_matcher == Blank

        @matcher.matcher = LastMatch.build([@matcher.matcher, new_matcher])
        @weight = nil
      end
    end
  end
end
