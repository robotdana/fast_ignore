# frozen_string_literal: true

class PathList
  class Matcher
    # @api private
    class CollectGitignore < Wrapper
      # @param collect_matcher [Matcher]
      # @param matcher [Matcher]
      # @return (see Matcher.build)
      def self.build(collect_matcher, matcher = Blank)
        dir_matcher = Mutable.new(matcher.dir_matcher)
        file_matcher = Mutable.new(matcher.file_matcher)
        matcher = Any.build([MatchIfDir.new(dir_matcher), MatchUnlessDir.new(file_matcher)])
        new(collect_matcher, matcher, dir_matcher, file_matcher)
      end

      # @param collect_matcher [Matcher]
      # @param matcher [Matcher]
      def initialize(collect_matcher, matcher = Blank, dir_matcher = matcher.dir_matcher,
        file_matcher = matcher.file_matcher)
        @collect_matcher = collect_matcher
        @loaded = [] # not frozen

        @dir_matcher = dir_matcher
        @file_matcher = file_matcher
        @matcher = matcher

        freeze
      end

      # @param (see Matcher#match)
      # @return (see Matcher#match)
      def match(candidate)
        collect(candidate) if @collect_matcher.match(candidate) == :allow

        @matcher.match(candidate)
      end

      # @param file [String]
      # @param root [String]
      # @return [void]
      def append(file, root:)
        return if @loaded.include?(file)

        @loaded << file

        new_matcher = PatternParser.build!(
          patterns_from_file: file,
          root: root,
          parser: PatternParser::Gitignore,
          default: Blank,
          polarity: :ignore
        )
        return if new_matcher == Blank

        @dir_matcher.matcher = LastMatch.build([@dir_matcher.matcher, new_matcher.dir_matcher])
        @file_matcher.matcher = LastMatch.build([@file_matcher.matcher, new_matcher.file_matcher])
      end

      # @return (see Matcher#inspect)
      def inspect
        "#{self.class}.new(\n#{
          @collect_matcher.inspect.gsub(/^/, '  ')
        },\n#{
          @matcher.inspect.gsub(/^/, '  ')
        }\n)"
      end

      # @return (see Matcher#weight)
      def weight
        @collect_matcher.weight + @matcher.weight
      end

      # @param (see Matcher#squashable_with?)
      # @return (see Matcher#squashable_with?)
      def squashable_with?(_other)
        false
      end

      # @return (see Matcher#dir_matcher)
      def dir_matcher
        new_parent = dup
        new_parent.matcher = @dir_matcher
        new_parent.collect_matcher = @collect_matcher.dir_matcher
        new_parent.freeze
      end

      # @return (see Matcher#polarity)
      def polarity
        :mixed
      end

      # @return (see Matcher#file_matcher)
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
