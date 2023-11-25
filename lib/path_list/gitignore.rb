# frozen_string_literal: true

class PathList
  # @api private
  class Gitignore
    # @param root [String, #to_s, nil] the root, when nil will find the $GIT_DIR like git does
    # @param config [Boolean] whether to load the configured core.excludesFile
    # @return [PathList::Matcher]
    def self.build(root:, config:)
      Cache.cache(root: root, gitignore_global: config) do
        new(root: root, config: config).matcher
      end
    end

    # @param (see .build)
    def initialize(root:, config:)
      @root = if root
        CanonicalPath.full_path(root)
      else
        find_root
      end
      @config = config
    end

    # @return [Matcher]
    def matcher
      collector = build_collector(@root)

      append(collector, @root, Gitconfig::CoreExcludesfile.path(repo_root: @root)) if @config
      append(collector, @root, '.git/info/exclude')
      append(collector, @root, '.gitignore')

      Matcher::LastMatch.build([collector, build_dot_git_matcher])
    end

    private

    def find_root
      home = ::Dir.home
      dir = pwd = ::Dir.pwd

      loop do
        return dir if ::File.exist?("#{dir}/.git")
        return pwd if dir.casecmp(home).zero? || dir.end_with?('/')

        dir = ::File.dirname(dir)
      end
    end

    def append(collector, root, path)
      return unless path

      collector.append(CanonicalPath.full_path_from(path, root), root: root)
    end

    def build_dot_git_matcher
      Matcher::PathRegexp.build([[:dir, '.git', :end_anchor]], :ignore)
    end

    def build_collector(root)
      root_re = TokenRegexp::Path.new_from_path(root)
      root_re_children = root_re.dup
      root_re_children.replace_end :dir

      Matcher::CollectGitignore.build(
        Matcher::MatchIfDir.new(
          Matcher::PathRegexp.build([root_re_children.parts, root_re.parts], :allow)
        ),
        Matcher::Allow
      )
    end
  end
end
