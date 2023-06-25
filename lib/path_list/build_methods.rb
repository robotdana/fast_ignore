# frozen_string_literal: true

class PathList
  module BuildMethods
    module ClassMethods
      def gitignore(root: nil, index: true, config: true)
        new.gitignore!(root: root, index: index, config: config)
      end

      def only(*patterns, from_file: nil, format: nil, root: nil)
        new.only!(*patterns, from_file: from_file, format: format, root: root)
      end

      def ignore(*patterns, from_file: nil, format: nil, root: nil)
        new.ignore!(*patterns, from_file: from_file, format: format, root: root)
      end

      def and(*path_lists)
        new.and(*path_lists)
      end

      def any(*path_lists)
        new.any(*path_lists)
      end
    end

    def gitignore(root: nil, index: true, config: true)
      dup.gitignore!(root: root, index: index, config: config)
    end

    def ignore(*patterns, from_file: nil, format: nil, root: nil)
      dup.ignore!(*patterns, from_file: from_file, format: format, root: root)
    end

    def only(*patterns, from_file: nil, format: nil, root: nil)
      dup.only!(*patterns, from_file: from_file, format: format, root: root)
    end

    def any(*path_lists)
      dup.any!(*path_lists)
    end

    def all(*path_lists)
      dup.all!(*path_lists)
    end

    def gitignore!(root: nil, index: true, config: true) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      root = PathExpander.expand_path_pwd(root || '.')

      if index && ::File.exist?(PathExpander.expand_path('.git/index', root))
        git_index = Matchers::GitIndex.new(root)
        git_indexes << git_index
        and_matcher(Matchers::LastMatch.new([Matchers::Allow, git_index]))

        return self
      end

      collector = Matchers::CollectGitignore.build(
        Matchers::MatchIfDir.new(
          Matchers::PathRegexp.build(RegexpBuilder.new_from_path(root, dir: nil, end_anchor: nil), true)
        )
      )

      if config
        global_gitignore = GlobalGitignore.path(root: root)
        collector.append(PathExpander.expand_path(global_gitignore, root), root: root) if global_gitignore
      end

      collector.append(PathExpander.expand_path('./.git/info/exclude', root), root: root)
      collector.append(PathExpander.expand_path('./.gitignore', root), root: root)

      and_matcher(
        Matchers::LastMatch.build([
          Matchers::Allow,
          collector,
          Matchers::PathRegexp.build(RegexpBuilder.new({ dir: { '\.git' => { end_anchor: nil } } }), false)
        ])
      )
    end

    def ignore!(*patterns, from_file: nil, format: nil, root: nil)
      and_matcher(Patterns.build(patterns, from_file: from_file, format: format, root: root).build)
    end

    def only!(*patterns, from_file: nil, format: nil, root: nil)
      and_matcher(Patterns.build(patterns, from_file: from_file, format: format, root: root, allow: true).build)
    end

    def and!(*path_lists)
      and_matcher(Matchers::All.build(path_lists.flat_map { |l| l.matcher })) # rubocop:disable Style/SymbolProc
    end

    def any!(*path_lists)
      and_matcher(Matchers::Any.build(path_lists.flat_map { |l| l.matcher })) # rubocop:disable Style/SymbolProc
    end

    private

    def any_use_index(new_matcher)
      @use_index = Matchers::Any.build([@use_index, new_matcher])

      self
    end

    def and_matcher(new_matcher)
      @matcher = Matchers::All.build([@matcher, new_matcher])
      @dir_matcher = nil
      @file_matcher = nil
      @compressed = nil

      self
    end
  end
end
