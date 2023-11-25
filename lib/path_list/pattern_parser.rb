# frozen_string_literal: true

class PathList
  # @api private
  class PatternParser
    Autoloader.autoload(self)

    class << self
      PARSERS = {
        glob_gitignore: GlobGitignore,
        gitignore: Gitignore,
        shebang: Shebang,
        exact: ExactPath
      }.freeze

      private_constant :PARSERS

      # @param patterns [Array<String, Array<String>>]
      # @param patterns_from_file: [String, nil]
      # @param format [:glob_gitignore, :gitignore, :shebang, :exact]
      # @param root [String, nil]
      # @param polarity [:allow, :ignore]
      # @return [PathList::Matcher]
      def build(patterns:, patterns_from_file:, format:, root:, polarity:)
        parser = PARSERS.fetch(format || :gitignore, nil)
        Cache.cache(
          patterns: patterns,
          patterns_from_file: patterns_from_file,
          parser: parser,
          root: root,
          polarity: polarity
        ) do
          raise Error, 'use only one of `*patterns` or `patterns_from_file:`' if !patterns.empty? && patterns_from_file
          raise Error, "`format:` must be one of #{PARSERS.keys.map(&:inspect).join(', ')}" unless parser

          root = CanonicalPath.full_path(root) if root

          if patterns_from_file
            patterns_from_file = CanonicalPath.full_path(patterns_from_file)
            root ||= ::File.dirname(patterns_from_file)
          else
            patterns = patterns.flatten.flat_map { |string| string.to_s.lines }
          end

          root ||= CanonicalPath.full_path(root)

          new(patterns: patterns, patterns_from_file: patterns_from_file, parser: parser, root: root,
              polarity: polarity, default: nil).matcher
        end
      end

      # @api private
      # like build but without the error checking and pre-processing for when we already know it's fine
      # root must be an absolute path
      # patterns_from_file must be an absolute path if given
      def build!(parser:, root:, polarity:, default:, patterns: nil, patterns_from_file: nil)
        Cache.cache(
          patterns: patterns,
          patterns_from_file: patterns_from_file,
          parser: parser,
          pwd: nil,
          root: root,
          polarity: polarity,
          default: default
        ) do
          new(
            patterns: patterns,
            patterns_from_file: patterns_from_file,
            parser: parser,
            root: root,
            polarity: polarity,
            default: default
          ).matcher
        end
      end
    end

    # @param patterns [Array<String, Array<String>>]
    # @param patterns_from_file: [String, nil]
    # @param parser [Class<GlobGitignore>, Class<Gitignore>, Class<Shebang>, Class<ExactPath>]
    # @param root [String]
    # @param polarity [:allow, :ignore]
    def initialize(parser:, root:, patterns:, patterns_from_file:, polarity:, default:)
      @patterns = patterns
      @patterns_from_file = patterns_from_file
      @parser = parser
      @root = root
      @polarity = polarity
      @default = default
    end

    # return [PathList::Matcher]
    def matcher
      if @polarity == :allow
        build_only_matcher
      else
        build_ignore_matcher
      end
    end

    private

    # return [PathList::Matcher]
    def build_only_matcher
      pattern_parsers = read_patterns.map { |pattern| @parser.new(pattern, @polarity, @root) }

      implicit = Matcher::Any.build(pattern_parsers.map(&:implicit_matcher))
      explicit = Matcher::LastMatch.build(pattern_parsers.map(&:matcher))

      return Matcher::Allow if implicit == Matcher::Blank && explicit == Matcher::Blank

      Matcher::LastMatch.build([Matcher::Ignore, implicit, explicit])
    end

    # @param default [PathList::Matcher] what to insert as the default
    # return [PathList::Matcher]
    def build_ignore_matcher(default = @default || Matcher::Allow)
      matchers = read_patterns.map { |pattern| @parser.new(pattern, @polarity, @root).matcher }
      matchers.unshift(default)
      Matcher::LastMatch.build(matchers)
    end

    def read_patterns
      if @patterns_from_file
        ::File.exist?(@patterns_from_file) ? ::File.readlines(@patterns_from_file) : []
      else
        @patterns || []
      end
    end
  end
end
