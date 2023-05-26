# frozen_string_literal: true

require 'strscan'
require 'set'

class PathList # rubocop:disable Metrics/ClassLength
  class Error < StandardError; end
  class GitconfigParseError < Error; end
  class NotSquashableError < Error; end

  require_relative 'path_list/global_gitignore'
  require_relative 'path_list/gitignore_rule_builder'
  require_relative 'path_list/gitignore_include_rule_builder'
  require_relative 'path_list/path_regexp_builder'
  require_relative 'path_list/gitignore_rule_scanner'
  require_relative 'path_list/matchers/base'
  require_relative 'path_list/matchers/list'
  require_relative 'path_list/matchers/any'
  require_relative 'path_list/matchers/all'
  require_relative 'path_list/matchers/wrapper'
  require_relative 'path_list/matchers/appendable'
  require_relative 'path_list/matchers/last_match'
  require_relative 'path_list/matchers/match_or_default'
  require_relative 'path_list/matchers/match_by_type'
  require_relative 'path_list/matchers/unmatchable'
  require_relative 'path_list/matchers/allow_any'
  require_relative 'path_list/matchers/shebang_regexp'
  require_relative 'path_list/gitconfig_parser'
  require_relative 'path_list/path_expander'
  require_relative 'path_list/candidate'
  require_relative 'path_list/matchers/within_dir'
  require_relative 'path_list/matchers/allow_any_parent'
  require_relative 'path_list/matchers/path_regexp'
  require_relative 'path_list/matchers/allow_parent_path_regexp'
  require_relative 'path_list/matchers/collect_gitignore'
  require_relative 'path_list/walkers/file_system'
  require_relative 'path_list/builders/shebang'
  require_relative 'path_list/builders/gitignore'
  require_relative 'path_list/builders/shebang_or_gitignore'
  require_relative 'path_list/builders/shebang_or_expand_path_gitignore'
  require_relative 'path_list/builders/expand_path_gitignore'
  require_relative 'path_list/patterns'

  class << self
    def gitignore(root: nil, append: :gitignore, format: :gitignore) # leftovers:keep
      new.gitignore!(root: root, append: append, format: format)
    end

    def only(*patterns, from_file: nil, format: nil, root: nil, append: false) # leftovers:keep
      new.only!(*patterns, from_file: from_file, format: format, root: root, append: append)
    end

    def ignore(*patterns, from_file: nil, format: nil, root: nil, append: false) # leftovers:keep
      new.ignore!(*patterns, from_file: from_file, format: format, root: root, append: append)
    end

    def and(*path_lists) # leftovers:keep
      new.and(*path_lists)
    end

    def any(*path_lists) # leftovers:keep
      new.any(*path_lists)
    end
  end

  include ::Enumerable

  attr_reader :matcher

  def initialize(matcher: Matchers::All.new([]))
    @matcher = matcher
  end

  def include?(path, directory: nil, content: nil, exists: nil)
    Walkers::FileSystem.allowed?(
      path,
      path_list: self,
      directory: directory,
      content: content,
      exists: exists
    )
  end

  alias_method :member?, :include?

  def match?(path, directory: nil, content: nil, exists: nil)
    Walkers::FileSystem.allowed?(
      path,
      path_list: self,
      directory: directory,
      content: content,
      exists: exists,
      include_directories: true
    )
  end

  def ===(path)
    Walkers::FileSystem.allowed?(path, path_list: self)
  end

  def to_proc
    method(:include?).to_proc
  end

  def each(root = '.', &block)
    return enum_for(:each, root) unless block
    return unless Walkers::FileSystem.allowed?(
      root, path_list: self, include_directories: true, parent_if_directory: true
    )

    Walkers::FileSystem.each(PathExpander.expand_dir(root), '', self, &block)
  end

  def dup
    self.class.new(matcher: @matcher)
  end

  def gitignore(root: nil, append: :gitignore, format: :gitignore) # leftovers:keep
    dup.gitignore!(root: root, append: append, format: format)
  end

  def ignore(*patterns, from_file: nil, format: nil, root: nil, append: false) # leftovers:keep
    dup.ignore!(*patterns, from_file: from_file, format: format, root: root, append: append)
  end

  def only(*patterns, from_file: nil, format: nil, root: nil, append: false) # leftovers:keep
    dup.only!(*patterns, from_file: from_file, format: format, root: root, append: append)
  end

  def any(*path_lists) # leftovers:keep
    dup.any!(*path_lists)
  end

  def all(*path_lists) # leftovers:keep
    dup.all!(*path_lists)
  end

  def gitignore!(root: nil, append: :gitignore, format: :gitignore)
    collect_gitignore = Matchers::CollectGitignore.new(root, format: format, append: append)

    ignore!(root: root, append: append, format: format)
    ignore!(from_file: GlobalGitignore.path(root: root), root: root || '.', append: append, format: format)
    ignore!(from_file: './.git/info/exclude', root: root || '.', append: append, format: format)
    ignore!(from_file: './.gitignore', root: root, append: append, format: format)
    ignore!('.git', root: '/')
    @matcher = Matchers::All.new([@matcher, collect_gitignore])

    self
  end

  def ignore!(*patterns, from_file: nil, format: nil, root: nil, append: nil)
    validate_options(patterns, from_file)

    and_pattern(
      Patterns.new(*patterns, from_file: from_file, format: format, root: root, append: append)
    )
    self
  end

  def only!(*patterns, from_file: nil, format: nil, root: nil, append: nil)
    validate_options(patterns, from_file)

    and_pattern(
      Patterns.new(*patterns, from_file: from_file, format: format, root: root, allow: true, append: append)
    )

    self
  end

  # TODO: handle merged appendables
  def and!(*path_lists)
    @matcher = Matchers::All.new([@matcher, *path_lists.flat_map(&:matcher)])

    self
  end

  # TODO: handle merged appendables
  def any!(*path_lists)
    @matcher = Matchers::All.new([@matcher, Matchers::Any.new(path_lists.flat_map(&:matcher))])

    self
  end

  private

  def and_pattern(pattern)
    @matcher = if pattern.label
      @matcher.append(pattern) || Matchers::All.new([@matcher, pattern.build])
    else
      Matchers::All.new([@matcher, pattern.build])
    end
  end

  def validate_options(patterns, from_file)
    if [(patterns unless patterns.empty?), from_file].compact.length > 1
      raise Error, 'Only use one of *patterns or from_file:'
    end
  end
end
