# frozen_string_literal: true

require 'set'
require 'strscan'

class FastIgnore
  class Error < StandardError; end

  require_relative 'fast_ignore/rule_groups'
  require_relative 'fast_ignore/rule_set'
  require_relative 'fast_ignore/global_gitignore'
  require_relative 'fast_ignore/rule_builder'
  require_relative 'fast_ignore/gitignore_rule_builder'
  require_relative 'fast_ignore/gitignore_include_rule_builder'
  require_relative 'fast_ignore/path_regexp_builder'
  require_relative 'fast_ignore/gitignore_rule_scanner'
  require_relative 'fast_ignore/rule'
  require_relative 'fast_ignore/rule_group'
  require_relative 'fast_ignore/unmatchable_rule'
  require_relative 'fast_ignore/shebang_rule'
  require_relative 'fast_ignore/gitconfig_parser'
  require_relative 'fast_ignore/path_expander'
  require_relative 'fast_ignore/root_candidate'
  require_relative 'fast_ignore/relative_candidate'

  include ::Enumerable

  def initialize(relative: false, root: nil, gitignore: :auto, follow_symlinks: false, **rule_group_builder_args)
    @relative = relative
    @follow_symlinks_method = ::File.method(follow_symlinks ? :stat : :lstat)
    @gitignore_enabled = gitignore
    @loaded_gitignore_files = ::Set[''] if gitignore
    @root = "#{PathExpander.expand_path(root.to_s, Dir.pwd)}/"
    @rule_groups = ::FastIgnore::RuleGroups.new(root: @root, gitignore: gitignore, **rule_group_builder_args)

    freeze
  end

  def each(&block)
    return enum_for(:each) unless block

    # dir_pwd = ::Dir.pwd
    # root_from_pwd = @root.start_with?(dir_pwd) ? ".#{@root.delete_prefix(dir_pwd)}" : @root

    each_recursive(@root, '', &block)
  end

  def allowed?(path, directory: nil, content: nil, exists: nil, include_directories: false) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    full_path = PathExpander.expand_path(path, @root)
    return false unless full_path.start_with?(@root)

    begin
      directory = directory.nil? ? @follow_symlinks_method.call(full_path).directory? : directory
    rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENOTDIR, ::Errno::ELOOP, ::Errno::ENAMETOOLONG
      exists = false if exists.nil?
      directory = false
    end

    return false if !include_directories && directory

    exists = exists.nil? ? ::File.exist?(full_path) : exists

    return false unless exists

    relative_path = full_path.delete_prefix(@root)
    load_gitignore_recursive(relative_path) if @gitignore_enabled

    candidate = ::FastIgnore::RootCandidate.new(full_path, nil, directory, content)

    @rule_groups.allowed_recursive?(candidate)
  end
  alias_method :===, :allowed?

  def to_proc
    method(:allowed?).to_proc
  end

  private

  def load_gitignore_recursive(path)
    paths = []
    while (path = ::File.dirname(path)) != '.'
      paths << path
    end

    paths.reverse_each { |p| load_gitignore(p) }
  end

  def load_gitignore(parent_path, check_exists: true)
    return if @loaded_gitignore_files.include?(parent_path)

    @rule_groups.append_subdir_gitignore(relative_path: parent_path + '.gitignore', check_exists: check_exists)

    @loaded_gitignore_files << parent_path
  end

  def each_recursive(parent_full_path, parent_relative_path, &block) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    children = ::Dir.children(parent_full_path)
    load_gitignore(parent_relative_path, check_exists: false) if @gitignore_enabled && children.include?('.gitignore')

    children.each do |filename|
      full_path = parent_full_path + filename
      relative_path = parent_relative_path + filename
      dir = @follow_symlinks_method.call(full_path).directory?
      candidate = ::FastIgnore::RootCandidate.new(full_path, filename, dir, nil)

      next unless @rule_groups.allowed_unrecursive?(candidate)

      if dir
        each_recursive(full_path + '/', relative_path + '/', &block)
      else
        yield(@relative ? relative_path : @root + relative_path)
      end
    rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENOTDIR, ::Errno::ELOOP, ::Errno::ENAMETOOLONG
      nil
    end
  end
end
