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
      root = PathExpander.expand_dir_pwd(root) if root

      if from_file
        @from_file = PathExpander.expand_path(from_file, root)
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

      @root = PathExpander.expand_dir_pwd(root)
      @format = BUILDERS.fetch(format || :gitignore, format)

      valid?
    end

    def build
      implicit_matcher, explicit_matcher = build_matchers

      if @label
        Matchers::Appendable.build(@label, default, implicit_matcher, explicit_matcher, self)
      elsif implicit_matcher == Matchers::Blank && explicit_matcher == Matchers::Blank
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

    def build_matchers
      patterns = read_patterns

      implicit = @allow ? build_implicit_matcher(patterns) : Matchers::Blank
      explicit = build_explicit_matcher(patterns)

      return [implicit, explicit] if !@allow || (implicit == Matchers::Blank && explicit == Matchers::Blank)

      implicit = Matchers::Any.build([implicit, build_implicit_root_matcher])

      [implicit, explicit]
    end

    private

    def build_implicit_root_matcher
      Builders::FullPath.build_implicit(@root, true, nil)
    end

    def build_implicit_matcher(patterns)
      Matchers::WithinDir.build(
        @root,
        Matchers::Any.build(
          patterns.map do |pattern|
            @format.build_implicit(pattern, @allow, @root)
          end
        )
      )
    end

    def build_explicit_matcher(patterns)
      Matchers::WithinDir.build(
        @root,
        Matchers::LastMatch.build(
          patterns.map do |pattern|
            @format.build(pattern, @allow, @root)
          end
        )
      )
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
