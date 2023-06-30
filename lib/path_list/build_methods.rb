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

      def all(*path_lists)
        new.all!(*path_lists)
      end

      def any(*path_lists)
        new.any!(*path_lists)
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
        @git_indexes ||= []
        @git_indexes << git_index
        and_matcher(Matchers::LastMatch.new([Matchers::Allow, git_index]))

        return self
      end

      root_re = PathRegexp.new_from_path(root)
      root_re_children = root_re.dup
      root_re_children.replace_end :dir

      collector = Matchers::CollectGitignore.build(
        Matchers::MatchIfDir.new(
          Matchers::PathRegexp.build([root_re_children.parts, root_re.parts], :allow)
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
          Matchers::PathRegexp.build([[:dir, '.git', :end_anchor]], :ignore)
        ])
      )
    end

    def ignore!(*patterns, from_file: nil, format: nil, root: nil)
      and_matcher(Patterns.build(patterns, from_file: from_file, format: format, root: root).build)
    end

    def only!(*patterns, from_file: nil, format: nil, root: nil)
      and_matcher(Patterns.build(patterns, from_file: from_file, format: format, root: root, polarity: :allow).build)
    end

    def all!(*path_lists)
      and_matcher(Matchers::All.build(path_lists.flat_map { |l| l.matcher })) # rubocop:disable Style/SymbolProc
    end

    def any!(*path_lists)
      and_matcher(Matchers::Any.build(path_lists.flat_map { |l| l.matcher })) # rubocop:disable Style/SymbolProc
    end

    private

    def and_matcher(new_matcher)
      @matcher = Matchers::All.build([@matcher, new_matcher])
      @dir_matcher = nil
      @file_matcher = nil
      @prepared = nil

      self
    end
  end
end
