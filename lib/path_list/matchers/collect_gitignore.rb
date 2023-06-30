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

      def match(candidate)
        collect(candidate) if @collect_matcher.match(candidate) == :allow

        @matcher.match(candidate)
      end

      def append(from_file, root: nil) # rubocop:disable Metrics/MethodLength
        return if @loaded.include?(from_file)

        @loaded << from_file

        patterns = Patterns.new(
          from_file: from_file,
          root: (root || PathExpander.expand_path_pwd('.')),
          format: Builder::Gitignore
        )
        new_matcher = patterns.build_ignore_matcher(Blank)

        return if new_matcher == Blank

        # new_matcher = new_matcher.prepare
        @dir_matcher.matcher = LastMatch.build([@dir_matcher.matcher, new_matcher.dir_matcher.prepare])
        @file_matcher.matcher = LastMatch.build([@file_matcher.matcher, new_matcher.file_matcher.prepare])
      end

      def inspect
        "#{self.class}.new(\n#{
          @collect_matcher.inspect.gsub(/^/, '  ')
        },\n#{
          @matcher.inspect.gsub(/^/, '  ')
        }\n)"
      end

      def weight
        @collect_matcher.weight + @matcher.weight
      end

      def squashable_with?(_)
        false
      end

      def prepare
        @dir_matcher.prepare
        @file_matcher.prepare
        @collect_matcher.prepare

        self

        # new_collect_matcher = @collect_matcher.prepare
        # if new_collect_matcher == @collect_matcher
        #   self
        # else
        #   new_parent = dup
        #   new_parent.collect_matcher = @collect_matcher.dir_matcher
        #   new_parent.freeze
        # end
      end

      def dir_matcher
        new_parent = dup
        new_parent.matcher = @dir_matcher
        new_parent.collect_matcher = @collect_matcher.dir_matcher
        new_parent.freeze
      end

      attr_reader :file_matcher

      protected

      attr_writer :matcher
      attr_writer :collect_matcher

      private

      def collect(candidate)
        if candidate.children.include?('.gitignore')
          append("#{candidate.full_path}/.gitignore", root: candidate.full_path)
        end
      end

      undef new_with_matcher
    end
  end
end
