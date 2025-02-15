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
          root = CanonicalPath.full_path(root) if root
          git_root = find_root(root)
          new(root: root || git_root, git_root: git_root, config: config).matcher
        end
      end

      # assumes root to be absolute
      def build!(root:, git_root:, config:)
        Cache.cache(root: root, pwd: nil, gitignore_global: config) do
          new(root: root, git_root: git_root, config: config).matcher
        end
      end

      def ignore_dot_git_matcher
        Matcher::LastMatch.build([
          Matcher::Allow,
          Matcher::PathRegexp.build([[:dir, '.git', :end_anchor]], :ignore)
        ])
      end

      private

      # TODO: GIT_CEILING_DIRECTORIES
      # GIT_DISCOVERY_ACROSS_FILESYSTEM
      def find_root(pwd)
        home = ::Dir.home
        dir = pwd ||= ::Dir.pwd

        loop do
          return dir if ::File.exist?("#{dir}/.git")
          return pwd if dir.casecmp(home).zero? || dir.end_with?('/')

          dir = ::File.dirname(dir)
        end
      end
    end

    # @param (see .build)
    def initialize(root:, git_root:, config:)
      @root = root
      @git_root = git_root
      @submodule_paths = find_submodule_paths
      @config = config
    end

    # @return [Matcher]
    def matcher
      git_dir = find_git_dir
      @matcher = Matcher::CollectGitignore.build(collect_matcher, Matcher::Allow)
      append(Gitconfig::CoreExcludesfile.path(git_dir: git_dir)) if @config
      append("#{git_dir}/info/exclude") if git_dir
      append('.gitignore')
      return build_submodule_matchers(@submodule_paths) if @submodule_paths

      @matcher
    end

    private

    def build_submodule_matchers(submodule_paths)
      Matcher::All.build([
        Matcher::LastMatch.build([
          @matcher,
          Matcher::LastMatch.build([
            submodule_paths.map do |submodule_path|
              match_path_or_children(submodule_path, :allow)
            end
          ])
        ]),

        Matcher::All.build(
          submodule_paths.map do |submodule_path|
            self.class.build!(root: submodule_path, git_root: submodule_path, config: @config)
          end
        )
      ])
    end

    def find_submodule_paths
      Gitconfig::FileParser
        .parse("#{@git_root}/.gitmodules")
        .submodule_paths
        &.map { |submodule_path| "#{@git_root}/#{submodule_path}" }
    end

    # TODO: GIT_DIR
    def find_git_dir
      dot_git = Candidate.new("#{@git_root}/.git")

      if dot_git.directory?
        dot_git.full_path
      else
        dot_git_content = ::File.read(dot_git.full_path)
        dot_git_content.delete_prefix!('gitdir: ')
        dot_git_content.chomp!
        CanonicalPath.full_path_from(
          dot_git_content, @git_root
        )
      end
    rescue ::IOError, ::SystemCallError
      nil
    end

    def append(path)
      return unless path

      @matcher.append(CanonicalPath.full_path_from(path, @root), root: @root)
    end

    def match_path_or_children(path, polarity)
      base_re = TokenRegexp::Path.new_from_path(path)
      children_re = base_re.dup
      children_re.replace_end :dir

      Matcher::PathRegexp.build([children_re.parts, base_re.parts], polarity)
    end

    def collect_matcher
      Matcher::MatchIfDir.new(
        match_path_or_children(@root, :allow)
      )
    end
  end
end
