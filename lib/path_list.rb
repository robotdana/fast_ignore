# frozen_string_literal: true

class PathList
  class Error < StandardError; end

  require_relative 'path_list/autoloader'
  Autoloader.autoload(self)

  include ::Enumerable
  extend ::Enumerable

  class << self
    def gitignore(root: nil, config: true)
      new.gitignore(root: root, config: config)
    end

    def ignore(*patterns, patterns_from_file: nil, format: :gitignore, root: nil)
      new.ignore(*patterns, patterns_from_file: patterns_from_file, format: format, root: root)
    end

    def only(*patterns, patterns_from_file: nil, format: :gitignore, root: nil)
      new.only(*patterns, patterns_from_file: patterns_from_file, format: format, root: root)
    end

    def union(path_list, *path_lists)
      path_list.union(*path_lists)
    end

    def intersection(path_list, *path_lists)
      path_list.intersection(*path_lists)
    end

    alias_method :all, :new
  end

  def initialize
    @matcher = Matcher::Allow
    @dir_matcher = nil
    @file_matcher = nil
  end

  def gitignore(root: nil, config: true)
    new_with_matcher(Matcher::All.build([
      @matcher,
      Gitignore.build(root: root, config: config),
      Gitignore.ignore_dot_git_matcher
    ]))
  end

  def ignore(*patterns, patterns_from_file: nil, format: :gitignore, root: nil)
    new_with_matcher(Matcher::All.build([
      @matcher,
      PatternParser.build(
        patterns: patterns,
        patterns_from_file: patterns_from_file,
        format: format,
        root: root,
        polarity: :ignore
      )
    ]))
  end

  def only(*patterns, patterns_from_file: nil, format: :gitignore, root: nil)
    new_with_matcher(Matcher::All.build([
      @matcher,
      PatternParser.build(
        patterns: patterns,
        patterns_from_file: patterns_from_file,
        format: format,
        root: root,
        polarity: :allow
      )
    ]))
  end

  def union(path_list, *path_lists)
    new_with_matcher(Matcher::Any.build([
      @matcher,
      path_list.matcher,
      *path_lists.map { |l| l.matcher } # rubocop:disable Style/SymbolProc
    ]))
  end

  def |(other)
    union(other)
  end

  def intersection(path_list, *path_lists)
    new_with_matcher(Matcher::All.build([
      @matcher,
      path_list.matcher,
      path_lists.map { |l| l.matcher } # rubocop:disable Style/SymbolProc
    ]))
  end

  def &(other)
    intersection(other)
  end

  def include?(path)
    full_path = CanonicalPath.full_path(path)
    candidate = Candidate.new(full_path)
    return false if !candidate.exists? || candidate.directory?

    recursive_match?(candidate.parent, dir_matcher) &&
      file_matcher.match(candidate) == :allow
  end
  alias_method :member?, :include?
  alias_method :===, :include?

  def to_proc
    method(:include?).to_proc
  end

  def match?(path, directory: nil, content: nil)
    full_path = CanonicalPath.full_path(path)
    content = content.slice(/\A#!.*$/) || '' if content
    candidate = Candidate.new(full_path, directory, content)

    recursive_match?(candidate.parent, dir_matcher) &&
      @matcher.match(candidate) == :allow
  end

  def each(root: '.', &block)
    return enum_for(:each, root: root) unless block

    root = CanonicalPath.full_path(root)
    root_candidate = Candidate.new(root)
    return self unless root_candidate.exists?
    return self unless recursive_match?(root_candidate.parent, dir_matcher)

    relative_root = root.end_with?('/') ? root : "#{root}/"

    recursive_each(root_candidate, relative_root, dir_matcher, file_matcher, &block)

    self
  end

  protected

  attr_reader :matcher

  def matcher=(new_matcher)
    @matcher = new_matcher
    @dir_matcher = nil
    @file_matcher = nil
  end

  private

  def recursive_each(candidate, relative_root, dir_matcher, file_matcher, &block)
    if candidate.directory?
      return unless dir_matcher.match(candidate) == :allow

      prepend_path = candidate.full_path.end_with?('/') ? candidate.full_path : "#{candidate.full_path}/"

      candidate.children.each do |filename|
        recursive_each(Candidate.new("#{prepend_path}#{filename}"), relative_root, dir_matcher, file_matcher, &block)
      end
    else
      return unless file_matcher.match(candidate) == :allow

      yield(candidate.full_path.delete_prefix(relative_root))
    end
  end

  def recursive_match?(candidate, matcher)
    return true unless candidate

    recursive_match?(candidate.parent, matcher) && matcher.match(candidate) == :allow
  end

  def new_with_matcher(matcher)
    path_list = self.class.new
    path_list.matcher = matcher
    path_list
  end

  def dir_matcher
    @dir_matcher ||= @matcher.dir_matcher
  end

  def file_matcher
    @file_matcher ||= @matcher.file_matcher
  end
end
