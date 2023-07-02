# frozen_string_literal: true

class PathList
  module Matchers
    class CollectGitignore < Wrapper
      def self.build(collect_matcher)
        new(collect_matcher)
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

      def append(file, root: nil)
        return if @loaded.include?(file)

        @loaded << file

        patterns = Patterns.new(
          read_from_file: file,
          root: (root || PathExpander.expand_path_pwd('.')),
          format: Builder::Gitignore
        )
        new_matcher = patterns.build_ignore_matcher(Blank)

        return if new_matcher == Blank

        @dir_matcher.matcher = LastMatch.build([@dir_matcher.matcher, new_matcher.dir_matcher])
        @file_matcher.matcher = LastMatch.build([@file_matcher.matcher, new_matcher.file_matcher])
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

      def dir_matcher
        new_parent = dup
        new_parent.matcher = @dir_matcher
        new_parent.collect_matcher = @collect_matcher.dir_matcher
        new_parent.freeze
      end

      attr_reader :file_matcher

      def ==(other)
        other.instance_of?(self.class) &&
          other.collect_matcher == @collect_matcher
      end

      protected

      attr_writer :matcher
      attr_accessor :collect_matcher
      attr_reader :root_downcase

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
