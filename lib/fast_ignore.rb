# frozen_string_literal: true

require_relative './fast_ignore/rule_set'
# require 'ruby-prof'

class FastIgnore
  include ::Enumerable

  unless ::RUBY_VERSION >= '2.5'
    require_relative 'fast_ignore/backports/delete_prefix_suffix'
    using ::FastIgnore::Backports::DeletePrefixSuffix
  end

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
      Array(ignore_rules),
      Array(ignore_files),
      gitignore,
      Array(include_rules),
      Array(include_files)
    )
  end

  def each(&block)
    if block_given?
      all_allowed.each(&block)
    else
      all_allowed.each
    end
  end

  def allowed?(path)
    path = ::File.expand_path(path)
    dir = ::File.directory?(path)
    @ignore.allowed_recursive?(path, dir) && @only.allowed_recursive?(path, dir)
  end

  def all_allowed
    allowed = []
    find_children(@root) do |path, dir|
      next false unless @ignore.allowed_unrecursive?(path, dir)
      next false unless @only.allowed_unrecursive?(path, dir)
      next true if dir
      next false unless ::File.readable?(path)

      allowed << prepare_path(path)

      false
    end
    allowed
  end

  private

  def rust_initialize( # rubocop:disable Metrics/ParameterLists
    relative,
    root,
    ignore_rules,
    ignore_files,
    gitignore,
    include_rules,
    include_files
  )
    @ignore = ::FastIgnore::RuleSet.new
    @only = ::FastIgnore::RuleSet.new(allow: true)
    @only.add_files(include_files)
    @only.add_rules(include_rules, root: root, expand_path: true)

    @ignore.add_rules(['.git'])
    @ignore.add_files([gitignore]) if gitignore && ::File.exist?(gitignore)
    @ignore.add_files(ignore_files)
    @ignore.add_rules(ignore_rules, root: root)
    @relative = relative
    @root = root
  end

  # rustify
  def prepare_path(path)
    @relative ? path.delete_prefix("#{@root}/") : path
  end

  def find_children(path, &block)
    Dir.each_child(path) do |child|
      begin
        child = ::File.join(path, child)
        dir = ::File.directory?(child)
        look_at_children = block.call child, dir
        find_children(child, &block) if look_at_children
      rescue Errno::ENOENT, Errno::EACCES, Errno::ENOTDIR, Errno::ELOOP, Errno::ENAMETOOLONG
        nil
      end
    end
  end
end
