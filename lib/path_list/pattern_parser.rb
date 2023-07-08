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
      def build(patterns, patterns_from_file: nil, format: nil, root: nil, polarity: :ignore)
        if (patterns && !patterns.empty?) && patterns_from_file
          raise Error, 'use only one of `*patterns` or `patterns_from_file:`'
        end

        parser = PARSERS.fetch(format || :gitignore, nil)
        raise Error, "`format:` must be one of #{PARSERS.keys.map(&:inspect).join(', ')}" unless parser

        root = PathExpander.expand_path_pwd(root) if root

        if patterns_from_file
          patterns_from_file = PathExpander.expand_path_pwd(patterns_from_file)
          root ||= ::File.dirname(patterns_from_file)
        else
          patterns = patterns.flatten.flat_map { |string| string.to_s.lines }
        end

        root ||= PathExpander.expand_path_pwd(root)

        new(patterns: patterns, patterns_from_file: patterns_from_file, parser: parser, root: root,
            polarity: polarity).matcher
      end
    end

    # @param patterns [Array<String, Array<String>>]
    # @param patterns_from_file: [String, nil]
    # @param parser [Class<GlobGitignore>, Class<Gitignore>, Class<Shebang>, Class<ExactPath>]
    # @param root [String]
    # @param polarity [:allow, :ignore]
    def initialize(parser:, root:, patterns: nil, patterns_from_file: nil, polarity: :ignore)
      @patterns = patterns
      @patterns_from_file = patterns_from_file
      @parser = parser
      @root = root
      @polarity = polarity
    end

    # return [PathList::Matcher]
    def matcher
      if @polarity == :allow
        build_only_matcher
      else
        build_ignore_matcher
      end
    end

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
    def build_ignore_matcher(default = Matcher::Allow)
      matchers = read_patterns.map { |pattern| @parser.new(pattern, @polarity, @root).matcher }
      matchers.unshift(default)
      Matcher::LastMatch.build(matchers)
    end

    private

    def read_patterns
      if @patterns_from_file
        ::File.exist?(@patterns_from_file) ? ::File.readlines(@patterns_from_file) : []
      else
        @patterns || []
      end
    end
  end
end
