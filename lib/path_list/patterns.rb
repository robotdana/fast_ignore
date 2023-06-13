# frozen_string_literal: true

class PathList
  class Patterns # rubocop:disable Metrics/ClassLength
    include ComparableInstance

    attr_writer :allow
    attr_reader :label

    BUILDERS = {
      glob: Builders::GlobGitignore,
      gitignore: Builders::Gitignore,
      shebang: Builders::Shebang
    }.freeze

    def initialize( # rubocop:disable Metrics/ParameterLists, Metrics/MethodLength, Metrics/AbcSize
      *patterns,
      from_file: nil,
      format: nil,
      root: nil,
      allow: false,
      label: nil,
      recursive: false
    )
      @label = label.to_sym if label
      root = PathExpander.expand_dir(root) if root

      if from_file
        @from_file = PathExpander.expand_path(from_file, root || '.')
        @exists = ::File.exist?(@from_file)
        if recursive
          @label ||= :"PathList::Patterns.new(from_file: \"./#{::File.basename(from_file)}\", recursive: true)"
        end
        root ||= ::File.dirname(from_file)
      else
        @patterns = patterns.flatten.flat_map { |string| string.to_s.lines }.freeze
      end

      @allow = allow
      @recursive = recursive

      @root = PathExpander.expand_dir(root || '.')
      @format = BUILDERS.fetch(format || :gitignore, format)

      valid?
    end

    def build
      implicit_matcher, explicit_matcher = build_matchers

      if @label
        Matchers::Appendable.build(@label, default, implicit_matcher, explicit_matcher, self)
      elsif implicit_matcher == Matchers::Null && explicit_matcher == Matchers::Null
        Matchers::Allow
      else
        Matchers::LastMatch.build([default, implicit_matcher, explicit_matcher])
      end
    end

    def build_accumulator(appendable_matcher) # rubocop:disable Metrics/MethodLength
      return unless @recursive

      Matchers::LastMatch.build([
        Matchers::Allow,
        Matchers::WithinDir.build(
          ::File.dirname(::File.dirname(@from_file)),
          Matchers::MatchIfDir.build(
            Matchers::AccumulateFromFile.build(
              "./#{::File.basename(@from_file)}",
              format: @format,
              appendable_matcher: appendable_matcher,
              label: @label
            )
          )
        )
      ])
    end

    def content?
      @patterns || @exists
    end

    def recursive?
      @recursive
    end

    def default
      @allow ? Matchers::Ignore : Matchers::Allow
    end

    def build_matchers # rubocop:disable Metrics/AbcSize
      matchers = read_patterns.flat_map { |p| @format.build(p, @allow, @root) }.compact
      implicit, explicit = matchers.partition(&:implicit?)
      return [Matchers::Null, Matchers::Null] if matchers.empty?

      implicit = Matchers::Any.build(implicit)
      explicit = Matchers::LastMatch.build(explicit)

      implicit = Matchers::WithinDir.build(@root, implicit)
      explicit = Matchers::WithinDir.build(@root, explicit)

      return [implicit, explicit] if !@allow || (implicit == Matchers::Null && explicit == Matchers::Null)

      implicit = Matchers::Any.build([implicit, build_root_matcher])

      [implicit, explicit]
    end

    private

    def build_root_matcher
      PathList::Matchers::MatchIfDir.build(Builders::FullPath.build(@root, true, nil))
    end

    def read_patterns
      if @from_file
        @exists ? ::File.readlines(@from_file) : []
      else
        @patterns
      end
    end

    def valid?
      raise Error, 'recursive: must only be used with from_file:' if @recursive && !@from_file

      raise Error, 'Only use one of *patterns, from_file:' if (@patterns && !@patterns.empty?) && @from_file

      unless @format.respond_to?(:build)
        raise Error, "format: is not a recognized format. must be in #{BUILDERS.keys} or be a format processor class"
      end
    end
  end
end
