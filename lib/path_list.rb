# frozen_string_literal: true

require 'strscan'
require 'set'

class PathList # rubocop:disable Metrics/ClassLength
  class Error < StandardError; end

  require_relative 'path_list/builders/full_path'
  require_relative 'path_list/comparable_instance'
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
    def gitignore(root: nil) # leftovers:keep
      new.gitignore!(root: root)
    end

    def only(*patterns, from_file: nil, format: nil, root: nil, label: nil, recursive: false) # leftovers:keep
      new.only!(*patterns, from_file: from_file, format: format, root: root, label: label, recursive: recursive)
    end

    def ignore(*patterns, from_file: nil, format: nil, root: nil, label: nil, recursive: false) # leftovers:keep
      new.ignore!(*patterns, from_file: from_file, format: format, root: root, label: label, recursive: recursive)
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

  def initialize(matcher: Matchers::Allow, appendable_matchers: {})
    @matcher = matcher
    @appendable_matchers = appendable_matchers
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
    self.class.new(matcher: @matcher, appendable_matchers: @appendable_matchers)
  end

  def gitignore(root: nil) # leftovers:keep
    dup.gitignore!(root: root)
  end

  def ignore(*patterns, from_file: nil, format: nil, root: nil, label: nil, recursive: false) # leftovers:keep
    dup.ignore!(*patterns, from_file: from_file, format: format, root: root, label: label, recursive: recursive)
  end

  def only(*patterns, from_file: nil, format: nil, root: nil, label: nil, recursive: false) # leftovers:keep
    dup.only!(*patterns, from_file: from_file, format: format, root: root, label: label, recursive: recursive)
  end

  def any(*path_lists) # leftovers:keep
    dup.any!(*path_lists)
  end

  def all(*path_lists) # leftovers:keep
    dup.all!(*path_lists)
  end

  APPENDABLE_GITIGNORE_LABEL = :'PathList::APPENDABLE_GITIGNORE_LABEL'
  private_constant :APPENDABLE_GITIGNORE_LABEL

  def gitignore!(root: nil)
    ignore!(label: APPENDABLE_GITIGNORE_LABEL, root: root)

    append!(label: APPENDABLE_GITIGNORE_LABEL, from_file: GlobalGitignore.path(root: root), root: root || '.')
    append!(label: APPENDABLE_GITIGNORE_LABEL, from_file: './.git/info/exclude', root: root || '.')
    append!(label: APPENDABLE_GITIGNORE_LABEL, from_file: './.gitignore', recursive: true, root: root)
    ignore!('.git', root: '/')

    self
  end

  def ignore!(*patterns, from_file: nil, format: nil, root: nil, label: nil, recursive: false)
    and_pattern(
      Patterns.new(*patterns, from_file: from_file, format: format, root: root, label: label, recursive: recursive)
    )

    self
  end

  def only!(*patterns, from_file: nil, format: nil, root: nil, label: nil, recursive: false)
    and_pattern(
      Patterns.new(*patterns, from_file: from_file, format: format, root: root, allow: true, label: label,
recursive: recursive)
    )

    self
  end

  def and!(*path_lists)
    and_matcher(Matchers::All.build(path_lists.flat_map(&:matcher)))
    and_pathlist_appendable_matchers(path_lists)

    self
  end

  def any!(*path_lists)
    and_matcher(Matchers::Any.build(path_lists.flat_map(&:matcher)))
    and_pathlist_appendable_matchers(path_lists)

    self
  end

  def append!(*patterns, label:, from_file: nil, format: nil, root: nil, recursive: false)
    pattern = Patterns.new(
      *patterns,
      from_file: from_file,
      format: format,
      root: root,
      label: label,
      recursive: recursive
    )

    append_pattern(pattern)
  end

  protected

  attr_reader :appendable_matchers

  private

  def and_pathlist_appendable_matchers(path_lists)
    and_appendable_matchers(*path_lists.flat_map { |p| p.appendable_matchers }) # rubocop:disable Style/SymbolProc
  end

  # TODO: handle merged appendables
  def and_appendable_matchers(*matchers)
    @appendable_matchers = @appendable_matchers.merge(*matchers) do |label|
      raise Error, "Appendable label #{label} already exists"
    end
  end

  def and_pattern(pattern)
    new_matcher = pattern.build

    and_appendable_matchers(pattern.label => new_matcher) if pattern.label

    and_matcher(new_matcher)
    and_recursive(pattern)
  end

  def and_recursive(pattern)
    and_matcher(pattern.build_accumulator(fetch_appendable(pattern.label))) if pattern.recursive?
  end

  def and_matcher(new_matcher)
    @matcher = Matchers::All.build([@matcher, new_matcher])
  end

  def append_pattern(pattern)
    appendable = fetch_appendable(pattern.label)
    appendable.append(pattern)
    and_recursive(pattern)
  end

  def fetch_appendable(label)
    @appendable_matchers.fetch(label)
  rescue KeyError
    raise Error, "Appendable label #{label} doesn't exist to append to"
  end
end
