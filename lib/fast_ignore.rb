# frozen_string_literal: true

require_relative './fast_ignore/backports'

require 'set'
require 'strscan'
require_relative 'fast_ignore/rule_groups'
require_relative 'fast_ignore/global_gitignore'
require_relative 'fast_ignore/rule_builder'
require_relative 'fast_ignore/gitignore_rule_builder'
require_relative 'fast_ignore/gitignore_include_rule_builder'
require_relative 'fast_ignore/path_regexp_builder'
require_relative 'fast_ignore/gitignore_rule_scanner'
require_relative 'fast_ignore/rule_group'
require_relative 'fast_ignore/matchers/unmatchable'
require_relative 'fast_ignore/matchers/shebang_regexp'
require_relative 'fast_ignore/root_candidate'
require_relative 'fast_ignore/relative_candidate'
require_relative 'fast_ignore/matchers/within_dir'
require_relative 'fast_ignore/matchers/allow_any_dir'
require_relative 'fast_ignore/matchers/allow_path_regexp'
require_relative 'fast_ignore/matchers/ignore_path_regexp'
require_relative 'fast_ignore/patterns'

class FastIgnore
  class Error < StandardError; end

  include ::Enumerable

  # :nocov:
  using ::FastIgnore::Backports::DeletePrefixSuffix if defined?(::FastIgnore::Backports::DeletePrefixSuffix)
  using ::FastIgnore::Backports::DirEachChild if defined?(::FastIgnore::Backports::DirEachChild)
  # :nocov:

  def initialize(root: nil, gitignore: :auto, **rule_group_builder_args)
    @gitignore_enabled = gitignore
    @loaded_gitignore_files = ::Set[''] if gitignore
    @root = "#{::File.expand_path(root.to_s, Dir.pwd)}/"
    @gitignore_root = @root.delete_suffix('/')
    @rule_groups = ::FastIgnore::RuleGroups.new(root: @root, gitignore: gitignore, **rule_group_builder_args)

    freeze
  end

  def each(&block)
    return enum_for(:each) unless block_given?

    # dir_pwd = ::Dir.pwd
    # root_from_pwd = @root.start_with?(dir_pwd) ? ".#{@root.delete_prefix(dir_pwd)}" : @root

    each_recursive(@root, '', &block)
  end

  def allowed?(path, directory: nil, content: nil)
    full_path = ::File.expand_path(path, @root)
    return false unless full_path.start_with?(@root)
    return false if directory.nil? ? ::File.lstat(full_path).directory? : directory

    load_gitignore_recursive(full_path) if @gitignore_enabled

    candidate = ::FastIgnore::RootCandidate.new(full_path, nil, directory, content)

    @rule_groups.allowed_recursive?(candidate)
  rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENOTDIR, ::Errno::ELOOP, ::Errno::ENAMETOOLONG
    false
  end
  alias_method :===, :allowed?

  def to_proc
    method(:allowed?).to_proc
  end

  private

  def load_gitignore_recursive(path)
    load_gitignore(path) until (path = ::File.dirname(path)) == @gitignore_root
  end

  def load_gitignore(parent_path)
    return if @loaded_gitignore_files.include?(parent_path)

    @rule_groups.append_subdir_gitignore(parent_path + '.gitignore')

    @loaded_gitignore_files << parent_path
  end

  def each_recursive(parent_full_path, parent_relative_path, &block) # rubocop:disable Metrics/MethodLength
    children = ::Dir.children(parent_full_path)
    load_gitignore(parent_full_path) if @gitignore_enabled && children.include?('.gitignore')

    children.each do |filename|
      begin
        full_path = parent_full_path + filename
        relative_path = parent_relative_path + filename
        dir = ::File.lstat(full_path).directory?
        candidate = ::FastIgnore::RootCandidate.new(full_path, filename, dir, nil)

        next unless @rule_groups.allowed_unrecursive?(candidate)

        if dir
          each_recursive(full_path + '/', relative_path + '/', &block)
        else
          yield relative_path
        end
      rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENOTDIR, ::Errno::ELOOP, ::Errno::ENAMETOOLONG
        nil
      end
    end
  end
end
