# frozen_string_literal: true

class PathList
  class Patterns
    BUILDERS = {
      glob: Builders::GlobGitignore,
      gitignore: Builders::Gitignore,
      shebang: Builders::Shebang
    }.freeze

    class << self
      def build(patterns, from_file: nil, format: nil, root: nil, allow: false) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        raise Error, 'Only use one of *patterns, from_file:' if (patterns && !patterns.empty?) && from_file

        format = BUILDERS.fetch(format || :gitignore, format)
        unless format.respond_to?(:build)
          raise Error, "format: is not a recognized format. use one of #{BUILDERS.keys} or a custom class"
        end

        root = PathExpander.expand_path_pwd(root) if root

        if from_file
          from_file = PathExpander.expand_path(from_file, root)
          root ||= ::File.dirname(from_file)
        else
          patterns = patterns.flatten.flat_map { |string| string.to_s.lines }.freeze
        end

        root ||= PathExpander.expand_path_pwd(root)

        new(patterns: patterns, from_file: from_file, format: format, root: root, allow: allow)
      end
    end

    def initialize(patterns: nil, from_file: nil, format: nil, root: nil, allow: false)
      @patterns = patterns
      @from_file = from_file
      @format = format
      @root = root
      @allow = allow
    end

    def build
      implicit_matcher, explicit_matcher = build_matchers

      if implicit_matcher == Matchers::Blank && explicit_matcher == Matchers::Blank
        Matchers::Allow
      else
        Matchers::LastMatch.build([default, implicit_matcher, explicit_matcher])
      end
    end

    def default
      @allow ? Matchers::Ignore : Matchers::Allow
    end

    def build_matchers
      patterns = read_patterns

      [build_implicit_matcher(patterns), build_explicit_matcher(patterns)]
    end

    private

    def build_implicit_matcher(patterns)
      return Matchers::Blank unless @allow

      Matchers::Any.build(patterns.map { |pattern| @format.build_implicit(pattern, @allow, @root) })
    end

    def build_explicit_matcher(patterns)
      Matchers::LastMatch.build(patterns.map { |pattern| @format.build(pattern, @allow, @root) })
    end

    def read_patterns
      if @from_file
        ::File.exist?(@from_file) ? ::File.readlines(@from_file) : []
      else
        @patterns
      end
    end
  end
end
