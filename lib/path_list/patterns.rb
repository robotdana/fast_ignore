# frozen_string_literal: true

class PathList
  class Patterns
    attr_reader :from_file
    attr_reader :root
    attr_reader :label
    attr_reader :allow
    attr_reader :format

    BUILDERS = {
      glob: Builders::GlobGitignore,
      gitignore: Builders::Gitignore,
      shebang: Builders::Shebang
    }.freeze

    def initialize(*patterns, from_file: nil, format: nil, root: nil, allow: false, append: nil) # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists
      @allow = allow
      @label = :"#{allow}_#{append}" if append
      root = PathExpander.expand_dir(root) if root

      if from_file
        @from_file = PathExpander.expand_path(from_file, root || '.')
        root ||= ::File.dirname(from_file)
      else
        @patterns = patterns.flatten.flat_map { |string| string.to_s.lines }.freeze
      end

      @root = PathExpander.expand_dir(root || '.')
      @format = BUILDERS.fetch(format || :gitignore, format)
    end

    def build
      implicit_matcher, explicit_matcher = build_matchers

      if @label
        Matchers::Appendable.new(@label, default, implicit_matcher, explicit_matcher) if @label
      elsif implicit_matcher.removable? && explicit_matcher.removable?
        Matchers::Allow
      else
        Matchers::LastMatch.build([default, implicit_matcher, explicit_matcher])
      end
    end

    def default
      @allow ? Matchers::Ignore : Matchers::Allow
    end

    def build_matchers
      matchers = read_patterns.flat_map { |p| format.build(p, @allow, @root) }.compact
      implicit, explicit = matchers.partition(&:implicit?)
      implicit = Matchers::Any.build(implicit)
      explicit = Matchers::LastMatch.build(explicit)

      return [implicit, explicit] if matchers.empty?

      implicit = Matchers::WithinDir.build(@root, implicit)
      explicit = Matchers::WithinDir.build(@root, explicit)
      return [implicit, explicit] unless @allow

      implicit_b, explicit_b = GitignoreIncludeRuleBuilder.new(@root).build_as_parent.partition(&:implicit?)
      implicit_b = Matchers::Any.build(implicit_b)
      explicit_b = Matchers::LastMatch.build(explicit_b)

      implicit = Matchers::Any.build([implicit, implicit_b])
      explicit = Matchers::LastMatch.build([explicit, explicit_b])

      [implicit, explicit]
    end

    private

    def read_patterns
      if from_file
        ::File.exist?(@from_file) ? ::File.readlines(@from_file) : []
      else
        @patterns
      end
    end
  end
end
