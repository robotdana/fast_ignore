# frozen_string_literal: true

class PathList
  module Matchers
    class CollectGitignore < Wrapper
      def self.build(collect_matcher, matcher = nil)
        new(collect_matcher, matcher)
      end

      def initialize(collect_matcher, matcher = nil)
        @collect_matcher = collect_matcher
        @loaded = [] # not frozen

        # matcher || is here just for test setup
        @dir_matcher = Mutable.new(matcher || Blank).dir_matcher
        @file_matcher = Mutable.new(matcher || Blank).file_matcher
        @matcher = matcher || Any.build([MatchIfDir.new(@dir_matcher), MatchUnlessDir.new(@file_matcher)])

        freeze
      end

      def inspect
        "#{self.class}.new(\n#{
          @collect_matcher.inspect.gsub(/^/, '  ')
        },\n#{
          @matcher.inspect.gsub(/^/, '  ')
        }\n)"
      end

      def squashable_with?(_)
        false
      end

      def weight
        @collect_matcher.weight + @matcher.weight
      end

      # TODO: how can i remove this candidate.directory? check
      # maybe move it to a matcher of its own?
      # although that's also a method call to an ivar so its maybe not worth it
      # we'd save the condition?
      def match(candidate)
        append('./.gitignore', root: candidate.full_path) if @collect_matcher.match(candidate) == :allow

        @matcher.match(candidate)
      end

      def dir_matcher
        new_parent = dup
        new_parent.matcher = @dir_matcher
        new_parent.collect_matcher = @collect_matcher.dir_matcher
        new_parent.freeze
      end

      def compress_self
        @dir_matcher.compress_self
        @file_matcher.compress_self
        new_collect_matcher = @collect_matcher.compress_self
        if new_collect_matcher != @collect_matcher
          new_parent = dup
          new_parent.collect_matcher = @collect_matcher.dir_matcher
          new_parent.freeze
        else
          self
        end
      end

      attr_reader :file_matcher

      undef new_with_matcher

      def append(from_file, root: nil)
        from_file = PathExpander.expand_path(from_file, root)

        return if @loaded.include?(from_file)

        @loaded << from_file

        patterns = Patterns.new(from_file: from_file, root: (root || PathExpander.expand_path_pwd('.')), allow: false,
                                format: Builders::Gitignore)
        _, new_matcher = patterns.build_matchers
        return if new_matcher == Blank

        @dir_matcher.matcher = LastMatch.build([@dir_matcher.matcher, new_matcher.dir_matcher])
        @file_matcher.matcher = LastMatch.build([@file_matcher.matcher, new_matcher.file_matcher])
      end

      protected

      attr_writer :matcher
      attr_writer :collect_matcher
    end
  end
end
