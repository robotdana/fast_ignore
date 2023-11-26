# frozen_string_literal: true

class PathList
  # @api private
  class Gitignore
    class << self
      # @param root [String, #to_s, nil] the root, when nil will find the $GIT_DIR like git does
      # @param config [Boolean] whether to load the configured core.excludesFile
      # @return [PathList::Matcher]
      def build(root:, config:)
        Cache.cache(root: root, gitignore_global: config) do
          root = if root
            CanonicalPath.full_path(root)
          else
            find_root
          end
          new(root: root, config: config).matcher
        end
      end

      # assumes root to be absolute
      def build!(root:, config:)
        Cache.cache(root: root, pwd: nil, gitignore_global: config) do
          new(root: root, config: config).matcher
        end
      end

      def ignore_dot_git_matcher
        Matcher::LastMatch.build([
          Matcher::Allow,
          Matcher::PathRegexp.build([[:dir, '.git', :end_anchor]], :ignore)
        ])
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
    end

    # @param (see .build)
    def initialize(root:, config:)
      @root = root
      @git_dir = find_git_dir
      @submodule_paths = find_submodule_paths
      @config = config
    end

    # @return [Matcher]
    def matcher
      @matcher = Matcher::CollectGitignore.build(collect_matcher, Matcher::Allow)
      append(Gitconfig::CoreExcludesfile.path(git_dir: @git_dir)) if @config
      require 'pry'
      binding.pry
      append("#{@git_dir}/info/exclude") if @git_dir
      append('.gitignore')
      return @matcher unless @submodule_paths

      Matcher::All.build([@matcher, *submodule_matchers])
    end

    private

    def submodule_matchers
      @submodule_paths.map do |submodule_path|
        self.class.build!(root: submodule_path, config: @config)
      end
    end

    def find_submodule_paths
      Gitconfig::FileParser
        .parse("#{@root}/.gitmodules")
        .submodule_paths
        &.map { |submodule_path| "#{@root}/#{submodule_path}" }
    end

    def find_git_dir
      dot_git = Candidate.new("#{@root}/.git")

      if dot_git.directory?
        dot_git.full_path
      elsif (dot_git_content = ::File.read(dot_git.full_path))
        dot_git_content.delete_prefix!('gitdir: ')
        dot_git_content.chomp!
        CanonicalPath.full_path_from(
          dot_git_content, @root
        )
      end
    rescue ::IOError, ::SystemCallError
      nil
    end

    def append(path)
      return unless path

      @matcher.append(CanonicalPath.full_path_from(path, @root), root: @root)
    end

    def collect_matcher
      root_re = TokenRegexp::Path.new_from_path(@root)
      root_re_children = root_re.dup
      root_re_children.replace_end :dir

      descendant_dirs_matcher = Matcher::MatchIfDir.new(
        Matcher::PathRegexp.build([root_re_children.parts, root_re.parts], :allow)
      )

      return descendant_dirs_matcher unless @submodule_paths

      Matcher::LastMatch.build([
        descendant_dirs_matcher,
        Matcher::ExactString.build(@submodule_paths, :ignore)
      ])
    end
  end
end
