# frozen_string_literal: true

require 'strscan'
require 'set'

class PathList # rubocop:disable Metrics/ClassLength
  class Error < StandardError; end
  class NotSquashableError < Error; end

  require_relative 'path_list/gitconfig_parse_error'
  require_relative 'path_list/global_gitignore'
  require_relative 'path_list/gitignore_rule_builder'
  require_relative 'path_list/gitignore_include_rule_builder'
  require_relative 'path_list/path_regexp_builder'
  require_relative 'path_list/gitignore_rule_scanner'
  require_relative 'path_list/matchers/base'
  require_relative 'path_list/matchers/unmatchable'
  require_relative 'path_list/matchers/list'
  require_relative 'path_list/matchers/allow'
  require_relative 'path_list/matchers/ignore'
  require_relative 'path_list/matchers/any'
  require_relative 'path_list/matchers/all'
  require_relative 'path_list/matchers/wrapper'
  require_relative 'path_list/matchers/appendable'
  require_relative 'path_list/matchers/last_match'
  require_relative 'path_list/matchers/shebang_regexp'
  require_relative 'path_list/gitconfig_parser'
  require_relative 'path_list/path_expander'
  require_relative 'path_list/candidate'
  require_relative 'path_list/matchers/within_dir'
  require_relative 'path_list/matchers/path_regexp'
  require_relative 'path_list/matchers/accumulate_from_file'
  require_relative 'path_list/walkers/file_system'
  require_relative 'path_list/builders/shebang'
  require_relative 'path_list/builders/gitignore'
  require_relative 'path_list/builders/glob_gitignore'
  require_relative 'path_list/patterns'
  require_relative 'path_list/matchers/match_if_dir'
  require_relative 'path_list/matchers/match_unless_dir'
  require_relative 'path_list/matchers/allow_any_dir'

  class << self
    def gitignore(root: nil, append: :gitignore, format: :gitignore) # leftovers:keep
      new.gitignore!(root: root, append: append, format: format)
    end

    def only(*patterns, from_file: nil, format: nil, root: nil, append: false, recursive: false) # leftovers:keep
      new.only!(*patterns, from_file: from_file, format: format, root: root, append: append, recursive: recursive)
    end

    def ignore(*patterns, from_file: nil, format: nil, root: nil, append: false, recursive: false) # leftovers:keep
      new.ignore!(*patterns, from_file: from_file, format: format, root: root, append: append, recursive: recursive)
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

  def initialize(matcher: Matchers::Allow)
    @matcher = matcher
  end

  def include?(path, directory: nil, content: nil, exists: nil)
    Walkers::FileSystem.include?(
      path,
      path_list: self,
      directory: directory,
      content: content,
      exists: exists
    )
  end

  alias_method :member?, :include?

  def match?(path, directory: nil, content: nil, exists: nil)
    Walkers::FileSystem.include?(
      path,
      path_list: self,
      directory: directory,
      content: content,
      exists: exists,
      as_parent: true
    )
  end

  def ===(path)
    Walkers::FileSystem.include?(path, path_list: self)
  end

  def to_proc
    method(:include?).to_proc
  end

  def each(root = '.', &block)
    return enum_for(:each, root) unless block
    return unless Walkers::FileSystem.include?(root, path_list: self, as_parent: true)

    Walkers::FileSystem.each(PathExpander.expand_dir(root), '', self, &block)
  end

  def dup
    self.class.new(matcher: @matcher)
  end

  def gitignore(root: nil, append: :gitignore, format: :gitignore) # leftovers:keep
    dup.gitignore!(root: root, append: append, format: format)
  end

  def ignore(*patterns, from_file: nil, format: nil, root: nil, append: false, recursive: false) # leftovers:keep
    dup.ignore!(*patterns, from_file: from_file, format: format, root: root, append: append, recursive: recursive)
  end

  def only(*patterns, from_file: nil, format: nil, root: nil, append: false, recursive: false) # leftovers:keep
    dup.only!(*patterns, from_file: from_file, format: format, root: root, append: append, recursive: recursive)
  end

  def any(*path_lists) # leftovers:keep
    dup.any!(*path_lists)
  end

  def all(*path_lists) # leftovers:keep
    dup.all!(*path_lists)
  end

  def gitignore!(root: nil, append: :gitignore, format: :gitignore)
    ignore!(root: root, append: append, format: format)
    ignore!(from_file: GlobalGitignore.path(root: root), root: root || '.', append: append, format: format)
    ignore!(from_file: './.git/info/exclude', root: root || '.', append: append, format: format)
    ignore!(from_file: './.gitignore', root: root, append: append, format: format, recursive: true)
    ignore!('.git', root: '/')

    self
  end

  def ignore!(*patterns, from_file: nil, format: nil, root: nil, append: nil, recursive: false)
    and_pattern(*patterns, from_file: from_file, format: format, root: root, append: append, recursive: recursive)

    self
  end

  def only!(*patterns, from_file: nil, format: nil, root: nil, append: nil, recursive: false)
     and_pattern(*patterns, from_file: from_file, format: format, root: root, allow: true, append: append, recursive: recursive)

    self
  end

  # TODO: handle merged appendables
  def and!(*path_lists)
    @matcher = Matchers::All.build([@matcher, *path_lists.flat_map(&:matcher)])

    self
  end

  # TODO: handle merged appendables
  def any!(*path_lists)
    @matcher = Matchers::All.build([@matcher, Matchers::Any.build(path_lists.flat_map(&:matcher))])

    self
  end

  private

  def and_pattern(*patterns, from_file: nil, format: nil, root: nil, allow: false, append: nil, recursive: false)
    pattern = Patterns.new(
      *patterns,
      from_file: from_file,
      format: format,
      root: root,
      allow: allow,
      append: append,
      recursive: recursive,
    )

    @matcher = (pattern.label && @matcher.append(pattern)) || Matchers::All.build([@matcher, pattern.build])
    @matcher = Matchers::All.build([@matcher, pattern.build_accumulator])
  end
end
