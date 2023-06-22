# frozen_string_literal: true

class PathList
  module Matchers
    class AppendGitignore < Wrapper
      def self.build(wrapper = Blank)
        new(wrapper)
      end

      def initialize(matcher)
        @loaded = []
        @matcher = matcher

        # not frozen!
      end

      def squashable_with?(_)
        false
      end

      if Invalid.is_a?(ComparableInstance)
        def eql?(other)
          super(other, except: [:@loaded])
        end
        alias_method :==, :eql?
      end

      def weight
        @weight ||= @matcher.weight + 1
      end

      def match(candidate)
        append('./.gitignore', root: candidate.full_path) if candidate.directory?

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

        @matcher = LastMatch.build([@matcher, new_matcher])
        @weight = nil
      end
    end
  end
end
