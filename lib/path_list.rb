# frozen_string_literal: true

class PathList
  class Error < StandardError; end

  require_relative 'path_list/autoloader'
  Autoloader.autoload(self)

  include ::Enumerable

  def initialize
    @matcher = Matcher::Allow
    @dir_matcher = nil
    @file_matcher = nil
  end

  def self.gitignore(root: nil, config: true)
    new.gitignore!(root: root, config: config)
  end

  def gitignore(root: nil, config: true)
    dup.gitignore!(root: root, config: config)
  end

  def gitignore!(root: nil, config: true)
    and_matcher(Gitignore.build(root: root, config: config))
  end

  def self.ignore(*patterns, read_from_file: nil, format: nil, root: nil)
    new.ignore!(*patterns, read_from_file: read_from_file, format: format, root: root)
  end

  def ignore(*patterns, read_from_file: nil, format: nil, root: nil)
    dup.ignore!(*patterns, read_from_file: read_from_file, format: format, root: root)
  end

  def ignore!(*patterns, read_from_file: nil, format: nil, root: nil)
    and_matcher(Patterns.build(patterns, read_from_file: read_from_file, format: format, root: root))
  end

  def self.only(*patterns, read_from_file: nil, format: nil, root: nil)
    new.only!(*patterns, read_from_file: read_from_file, format: format, root: root)
  end

  def only(*patterns, read_from_file: nil, format: nil, root: nil)
    dup.only!(*patterns, read_from_file: read_from_file, format: format, root: root)
  end

  def only!(*patterns, read_from_file: nil, format: nil, root: nil)
    and_matcher(Patterns.build(patterns, read_from_file: read_from_file, format: format, root: root, polarity: :allow))
  end

  def union(*path_lists)
    dup.union!(*path_lists)
  end

  def |(other)
    dup.union!(other)
  end

  def union!(*path_lists)
    self.matcher = Matcher::Any.build([@matcher, *path_lists.map { |l| l.matcher }]) # rubocop:disable Style/SymbolProc

    self
  end

  def intersection(*path_lists)
    dup.intersection!(*path_lists)
  end

  def &(other)
    dup.intersection!(other)
  end

  def intersection!(*path_lists)
    and_matcher(Matcher::All.build(path_lists.map { |l| l.matcher })) # rubocop:disable Style/SymbolProc
  end

  def include?(path)
    full_path = PathExpander.expand_path_pwd(path)
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
    full_path = PathExpander.expand_path_pwd(path)
    content = content.slice(/\A#!.*$/)&.downcase || '' if content
    candidate = Candidate.new(full_path, directory, content)

    recursive_match?(candidate.parent, dir_matcher) &&
      @matcher.match(candidate) == :allow
  end

  def each(root = '.', &block)
    return enum_for(:each, root) unless block

    root = PathExpander.expand_path_pwd(root)
    root_candidate = Candidate.new(root)
    return self unless root_candidate.exists?
    return self unless recursive_match?(root_candidate.parent, dir_matcher)

    relative_root = root == '/' ? root : "#{root}/"

    recursive_each(root_candidate, relative_root, dir_matcher, file_matcher, &block)

    self
  end

  protected

  attr_reader :matcher

  private

  def recursive_each(candidate, relative_root, dir_matcher, file_matcher, &block)
    if candidate.directory?
      return unless dir_matcher.match(candidate) == :allow

      candidate.child_candidates.each do |child|
        recursive_each(child, relative_root, dir_matcher, file_matcher, &block)
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

  def and_matcher(new_matcher)
    self.matcher = Matcher::All.build([@matcher, new_matcher])

    self
  end

  def matcher=(new_matcher)
    @matcher = new_matcher
    @dir_matcher = nil
    @file_matcher = nil
  end

  def dir_matcher
    @dir_matcher ||= @matcher.dir_matcher
  end

  def file_matcher
    @file_matcher ||= @matcher.file_matcher
  end
end
