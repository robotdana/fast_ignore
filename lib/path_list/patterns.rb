# frozen_string_literal: true

class PathList
  class Patterns
    BUILDERS = {
      glob: Builder::GlobGitignore,
      gitignore: Builder::Gitignore,
      shebang: Builder::Shebang,
      exact: Builder::ExactPath
    }.freeze

    class << self
      def build(patterns, read_from_file: nil, format: nil, root: nil, polarity: :ignore)
        if (patterns && !patterns.empty?) && read_from_file
          raise Error, 'use only one of `*patterns` or `read_from_file:`'
        end

        format = BUILDERS.fetch(format || :gitignore, nil)
        raise Error, "`format:` must be one of #{BUILDERS.keys.map(&:inspect).join(', ')}" unless format

        root = PathExpander.expand_path_pwd(root) if root

        if read_from_file
          read_from_file = PathExpander.expand_path(read_from_file, root)
          root ||= ::File.dirname(read_from_file)
        else
          patterns = patterns.flatten.flat_map { |string| string.to_s.lines }
        end

        root ||= PathExpander.expand_path_pwd(root)

        new(patterns: patterns, read_from_file: read_from_file, format: format, root: root, polarity: polarity)
      end
    end

    def initialize(patterns: nil, read_from_file: nil, format: nil, root: nil, polarity: :ignore)
      @patterns = patterns
      @read_from_file = read_from_file
      @format = format
      @root = root
      @polarity = polarity
    end

    def build
      if @polarity == :allow
        build_only_matcher
      else
        build_ignore_matcher
      end
    end

    def build_only_matcher
      pattern_builders = read_patterns.map { |rule| @format.new(rule, @polarity, @root) }

      implicit = Matchers::Any.build(pattern_builders.map(&:build_implicit))
      explicit = Matchers::LastMatch.build(pattern_builders.map(&:build))

      return Matchers::Allow if implicit == Matchers::Blank && explicit == Matchers::Blank

      Matchers::LastMatch.build([Matchers::Ignore, implicit, explicit])
    end

    def build_ignore_matcher(default = Matchers::Allow)
      matchers = read_patterns
      matchers.map! { |rule| @format.new(rule, @polarity, @root).build }
      matchers.unshift(default)
      Matchers::LastMatch.build(matchers)
    end

    private

    def read_patterns
      if @read_from_file
        ::File.exist?(@read_from_file) ? ::File.readlines(@read_from_file) : []
      else
        @patterns
      end
    end
  end
end
