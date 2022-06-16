# frozen_string_literal: true

require 'strscan'
require 'set'

class FastIgnore
  class Error < StandardError; end

  require_relative 'fast_ignore/rule_set'
  require_relative 'fast_ignore/global_gitignore'
  require_relative 'fast_ignore/gitignore_rule_builder'
  require_relative 'fast_ignore/gitignore_include_rule_builder'
  require_relative 'fast_ignore/path_regexp_builder'
  require_relative 'fast_ignore/gitignore_rule_scanner'
  require_relative 'fast_ignore/matchers/last_match'
  require_relative 'fast_ignore/matchers/match_or_default'
  require_relative 'fast_ignore/matchers/match_by_type'
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
  require_relative 'fast_ignore/walkers/file_system'
  require_relative 'fast_ignore/walkers/gitignore_collecting_file_system'
  require_relative 'fast_ignore/builders/shebang'
  require_relative 'fast_ignore/builders/gitignore'
  require_relative 'fast_ignore/builders/shebang_or_gitignore'
  require_relative 'fast_ignore/builders/shebang_or_expand_path_gitignore'
  require_relative 'fast_ignore/builders/expand_path_gitignore'
  require_relative 'fast_ignore/patterns'
  require_relative 'fast_ignore/path_list'

  include ::Enumerable

  def initialize( # rubocop:disable Metrics/ParameterLists, Metrics/MethodLength
    relative: false,
    root: '.',
    ignore_rules: nil,
    ignore_files: nil,
    gitignore: true,
    include_rules: nil,
    include_files: nil,
    argv_rules: nil
  )
    @root = ::FastIgnore::PathExpander.expand_dir(root)
    @path_list = ::FastIgnore::PathList.new
    @relative = relative

    Array(ignore_files).each do |f|
      path = ::FastIgnore::PathExpander.expand_path(f, @root)
      @path_list.ignore!(from_file: path, format: :shebang_or_gitignore)
    end
    Array(include_files).each do |f|
      path = ::FastIgnore::PathExpander.expand_path(f, @root)
      @path_list.only!(from_file: path, format: :shebang_or_gitignore)
    end

    @path_list.gitignore!(root: @root, format: :shebang_or_gitignore) if gitignore

    @path_list.ignore!(ignore_rules, root: @root, format: :shebang_or_gitignore)
      .only!(include_rules, root: @root, format: :shebang_or_gitignore)
      .only!(argv_rules, root: @root, format: :shebang_or_expand_path_gitignore)
      .only!(@root, root: '/')
  end

  def allowed?(path, directory: nil, content: nil, exists: nil, include_directories: false)
    @path_list.allowed?(
      ::FastIgnore::PathExpander.expand_path(path, @root),
      directory: directory,
      content: content,
      exists: exists,
      include_directories: include_directories
    )
  end

  def ===(path)
    @path_list === ::FastIgnore::PathExpander.expand_path(path, @root) # rubocop:disable Style/CaseEquality
  end

  def to_proc
    @path_list.to_proc
  end

  def each(&block)
    @path_list.each(root: @root, prefix: @relative ? '' : @root, &block)
  end
end
