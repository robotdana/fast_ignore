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
require_relative 'fast_ignore/walkers/file_system'
require_relative 'fast_ignore/walkers/gitignore_collecting_file_system'
require_relative 'fast_ignore/gitignore_rule_group'

class FastIgnore
  class Error < StandardError; end

  include ::Enumerable

  # :nocov:
  using ::FastIgnore::Backports::DeletePrefixSuffix if defined?(::FastIgnore::Backports::DeletePrefixSuffix)
  using ::FastIgnore::Backports::DirEachChild if defined?(::FastIgnore::Backports::DirEachChild)
  # :nocov:

  def initialize(root: nil, gitignore: :auto, **rule_group_builder_args)
    @root = "#{::File.expand_path(root.to_s, Dir.pwd)}/"
    rule_groups = ::FastIgnore::RuleGroups.new(root: @root, gitignore: gitignore, **rule_group_builder_args)

    walker_class = gitignore ? ::FastIgnore::Walkers::GitignoreCollectingFileSystem : ::FastIgnore::Walkers::FileSystem
    @walker = walker_class.new(rule_groups)
    freeze
  end

  def allowed?(path, directory: nil, content: nil)
    @walker.allowed?(path, directory: directory, content: content)
  end
  alias_method :===, :allowed?

  def to_proc
    method(:allowed?).to_proc
  end

  def each(root = ::Dir.pwd, &block)
    return enum_for(:each, root) unless block_given?

    root = "#{::File.expand_path(root.to_s, Dir.pwd)}/"
    @walker.each(root, '', &block)
  end
end
