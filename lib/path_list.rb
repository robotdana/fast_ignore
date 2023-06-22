# frozen_string_literal: true

require 'strscan'
require 'set'

class PathList # rubocop:disable Metrics/ClassLength
  class Error < StandardError; end

  require_relative 'path_list/autoloader'
  include Autoloader

  class << self
    def gitignore(root: nil)
      new.gitignore!(root: root)
    end

    def only(*patterns, from_file: nil, format: nil, root: nil)
      new.only!(*patterns, from_file: from_file, format: format, root: root)
    end

    def ignore(*patterns, from_file: nil, format: nil, root: nil)
      new.ignore!(*patterns, from_file: from_file, format: format, root: root)
    end

    def and(*path_lists)
      new.and(*path_lists)
    end

    def any(*path_lists)
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

    Walkers::FileSystem.each(PathExpander.expand_dir_pwd(root), '', self, &block)
  end

  def dup
    self.class.new(matcher: @matcher)
  end

  def gitignore(root: nil)
    dup.gitignore!(root: root)
  end

  def ignore(*patterns, from_file: nil, format: nil, root: nil)
    dup.ignore!(*patterns, from_file: from_file, format: format, root: root)
  end

  def only(*patterns, from_file: nil, format: nil, root: nil)
    dup.only!(*patterns, from_file: from_file, format: format, root: root)
  end

  def any(*path_lists)
    dup.any!(*path_lists)
  end

  def all(*path_lists)
    dup.all!(*path_lists)
  end

  def gitignore!(root: nil) # rubocop:disable Metrics/MethodLength
    root = PathExpander.expand_path_pwd(root || '.')

    appendable = Matchers::AppendGitignore.build
    appendable.append(GlobalGitignore.path(root: root), root: root)
    appendable.append('./.git/info/exclude', root: root)
    appendable.append('./.gitignore', root: root)

    and_matcher(
      Matchers::LastMatch.build([
        Matchers::Allow,
        Matchers::PathRegexpWrapper.build(
          RegexpBuilder.new([:start_anchor, Regexp.escape(root), [[:dir], [:end_anchor]]]),
          appendable
        ),
        Matchers::PathRegexp.build(RegexpBuilder.new([:dir, '\.git', :end_anchor]), false)
      ])
    )

    self
  end

  def ignore!(*patterns, from_file: nil, format: nil, root: nil)
    and_pattern(Patterns.build(patterns, from_file: from_file, format: format, root: root))

    self
  end

  def only!(*patterns, from_file: nil, format: nil, root: nil)
    and_pattern(Patterns.build(patterns, from_file: from_file, format: format, root: root, allow: true))

    self
  end

  def and!(*path_lists)
    and_matcher(Matchers::All.build(path_lists.flat_map(&:matcher)))

    self
  end

  def any!(*path_lists)
    and_matcher(Matchers::Any.build(path_lists.flat_map(&:matcher)))

    self
  end

  private

  def and_pattern(pattern)
    new_matcher = pattern.build

    and_matcher(new_matcher)
  end

  def and_matcher(new_matcher)
    @matcher = Matchers::All.build([@matcher, new_matcher])
  end
end
