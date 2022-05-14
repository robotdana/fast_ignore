# frozen_string_literal: true

require 'strscan'
require 'set'

class FastIgnore
  class Error < StandardError; end

  require_relative 'fast_ignore/rule_set'
  require_relative 'fast_ignore/appendable_patterns'
  require_relative 'fast_ignore/rule_set_builder'
  require_relative 'fast_ignore/global_gitignore'
  require_relative 'fast_ignore/gitignore_rule_builder'
  require_relative 'fast_ignore/gitignore_include_rule_builder'
  require_relative 'fast_ignore/path_regexp_builder'
  require_relative 'fast_ignore/gitignore_rule_scanner'
  require_relative 'fast_ignore/rule_group'
  require_relative 'fast_ignore/matchers/unmatchable'
  require_relative 'fast_ignore/matchers/shebang_regexp'
  require_relative 'fast_ignore/gitconfig_parser'
  require_relative 'fast_ignore/path_expander'
  require_relative 'fast_ignore/candidate'
  require_relative 'fast_ignore/relative_candidate'
  require_relative 'fast_ignore/matchers/within_dir'
  require_relative 'fast_ignore/matchers/allow_any_dir'
  require_relative 'fast_ignore/matchers/allow_path_regexp'
  require_relative 'fast_ignore/matchers/ignore_path_regexp'
  require_relative 'fast_ignore/patterns'
  require_relative 'fast_ignore/walkers/file_system'
  require_relative 'fast_ignore/walkers/gitignore_collecting_file_system'
  require_relative 'fast_ignore/builders/shebang'
  require_relative 'fast_ignore/builders/gitignore'
  require_relative 'fast_ignore/builders/shebang_or_gitignore'
  require_relative 'fast_ignore/path_list_methods'
  require_relative 'fast_ignore/path_list'

  include ::Enumerable
  # extend ::FastIgnore::Builder

  def initialize(relative: false, root: '.', **rule_group_builder_args)
    @root = ::FastIgnore::PathExpander.expand_dir(root)
    @rule_set = ::FastIgnore::RuleSetBuilder.build(root: @root, **rule_group_builder_args)
    @relative = relative
  end

  def allowed?(path, directory: nil, content: nil, exists: nil, include_directories: false)
    @rule_set.query.allowed?(
      ::FastIgnore::PathExpander.expand_path(path, @root),
      rule_set: @rule_set,
      directory: directory,
      content: content,
      exists: exists,
      include_directories: include_directories
    )
  end
  alias_method :===, :allowed?

  def to_proc
    method(:allowed?).to_proc
  end

  def each(&block)
    return enum_for(:each) unless block

    prefix = @relative ? '' : @root

    @rule_set.query.each(@root, prefix, @rule_set, &block)
  end
end
