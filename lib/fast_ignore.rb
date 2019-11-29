# frozen_string_literal: true

require_relative './fast_ignore/rule_set'
require 'helix_runtime'
require 'fast_ignore/native'
require 'find'

class FastIgnore
  include ::Enumerable

  def initialize( # rubocop:disable Metrics/ParameterLists
    relative: false,
    root: ::Dir.pwd,
    ignore_rules: nil,
    ignore_files: nil,
    gitignore: ::File.join(root, '.gitignore'),
    include_rules: nil,
    include_files: nil
  )
    rust_initialize(
      relative,
      root,
      ignore_rules,
      ignore_files,
      gitignore,
      include_rules,
      include_files
    )
  end

  def each(&block)
    if block_given?
      each_allowed(&block)
    else
      enum_for(:each_allowed)
    end
  end

  def allowed?(path)
    allowed_recursive?(::File.expand_path(path))
  end

  private

  unless ::RUBY_VERSION >= '2.5'
    require_relative 'fast_ignore/backports/delete_prefix_suffix'
    using ::FastIgnore::Backports::DeletePrefixSuffix
  end

  attr_reader :relative
  alias_method :relative?, :relative
  attr_reader :root

  def rust_initialize( # rubocop:disable Metrics/ParameterLists
    relative,
    root,
    ignore_rules,
    ignore_files,
    gitignore,
    include_rules,
    include_files
  )
    @ignore = ::FastIgnore::RuleSet.new(:ignore)
    @only = ::FastIgnore::RuleSet.new(:only)
    @ignore.add_rules('.git')
    @ignore.add_files(gitignore) if gitignore && ::File.exist?(gitignore)
    @ignore.add_files(ignore_files)
    @ignore.add_rules(ignore_rules, root: root)
    @only.add_files(include_files)
    @only.add_rules(include_rules, root: root, expand_path: true)
    @relative = relative
    @root = root
  end

  def each_allowed(&block)
    if @only.globbable?
      glob_allowed(&block)
    else
      find_allowed(&block)
    end
  end

  def allowed_recursive?(path, dir = ::File.directory?(path))
    @allowed_recursive ||= {}
    @allowed_recursive.fetch(path) do
      @allowed_recursive[path] = @ignore.allowed_recursive?(path, dir) &&
        @only.allowed_recursive?(path, dir)
    end
  end

  # rustify
  def glob_allowed
    seen = {}
    @only.glob do |path|
      next if seen[path]

      seen[path] = true
      next if ::File.directory?(path)
      next unless ::File.readable?(path)
      next unless @ignore.allowed_recursive?(path, false)

      yield prepare_path(path)
    end
  end

  # rustify
  def find_allowed
    ::Find.find(root) do |path|
      next if path == root
      next unless ::File.readable?(path)

      dir = ::File.directory?(path)
      next ::Find.prune unless @ignore.allowed_unrecursive?(path, dir)
      next if dir
      next unless @only.allowed_recursive?(path, false)

      yield prepare_path(path)
    end
  end

  # rustify
  def prepare_path(path)
    @relative ? path.delete_prefix("#{root}/") : path
  end
end
