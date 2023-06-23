# frozen_string_literal: true

class PathList
  module BuildMethods
    # frozen_string_literal: true

    module ClassMethods
      def gitignore(root: nil)
        new.gitignore!(root: root)
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

    def gitignore(root: nil)
      dup.gitignore!(root: root)
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

    def gitignore!(root: nil) # rubocop:disable Metrics/MethodLength
      root = PathExpander.expand_path_pwd(root || '.')

      collector = Matchers::CollectGitignore.build(RegexpBuilder.new_from_path(root, [[[:dir], [:end_anchor]]]))
      collector.append(GlobalGitignore.path(root: root), root: root)
      collector.append('./.git/info/exclude', root: root)
      collector.append('./.gitignore', root: root)

      and_matcher(
        Matchers::LastMatch.build([
          Matchers::Allow,
          collector,
          Matchers::PathRegexp.build(RegexpBuilder.new([:dir, '\.git', :end_anchor]), false)
        ])
      )

      self
    end

    def ignore!(*patterns, from_file: nil, format: nil, root: nil)
      and_matcher(Patterns.build(patterns, from_file: from_file, format: format, root: root).build)

      self
    end

    def only!(*patterns, from_file: nil, format: nil, root: nil)
      and_matcher(Patterns.build(patterns, from_file: from_file, format: format, root: root, allow: true).build)

      self
    end

    def and!(*path_lists)
      and_matcher(Matchers::All.build(path_lists.flat_map { |l| l.matcher })) # rubocop:disable Style/SymbolProc

      self
    end

    def any!(*path_lists)
      and_matcher(Matchers::Any.build(path_lists.flat_map { |l| l.matcher })) # rubocop:disable Style/SymbolProc

      self
    end

    private

    def and_matcher(new_matcher)
      @matcher = Matchers::All.build([@matcher, new_matcher])
    end
  end
end
