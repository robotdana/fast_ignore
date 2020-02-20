# frozen_string_literal: true

require_relative './fast_ignore/rule_set_builder'

class FastIgnore
  include ::Enumerable

  unless ::RUBY_VERSION >= '2.5'
    require_relative 'fast_ignore/backports/delete_prefix_suffix'
    using ::FastIgnore::Backports::DeletePrefixSuffix
  end

  unless ::RUBY_VERSION >= '2.5'
    require_relative 'fast_ignore/backports/dir_each_child'
    using ::FastIgnore::Backports::DirEachChild
  end

  def initialize( # rubocop:disable Metrics/ParameterLists, Metrics/MethodLength, Metrics/AbcSize
    relative: false,
    root: ::Dir.pwd,
    ignore_rules: nil,
    ignore_files: nil,
    gitignore: ::File.join(root, '.gitignore'),
    include_rules: nil,
    include_files: nil
  )
    @root = root.delete_suffix('/')
    @root_trailing_slash = "#{@root}/"
    ignore = ::FastIgnore::RuleSetBuilder.new(root: @root)
    only = ::FastIgnore::RuleSetBuilder.new(allow: true, root: @root)
    only.add_files(Array(include_files))
    only.add_rules(Array(include_rules), expand_path: true)
    @only = only.rule_set

    ignore.add_rules(['.git'])
    ignore.add_files([gitignore]) if gitignore && ::File.exist?(gitignore)
    ignore.add_files(Array(ignore_files))
    ignore.add_rules(Array(ignore_rules))
    @ignore = ignore.rule_set
    @relative = relative
  end

  def each(&block)
    if block_given?
      all_allowed(&block)
    else
      enum_for(:all_allowed)
    end
  end

  def allowed?(path)
    path = ::File.expand_path(path)
    dir = ::File.directory?(path)
    @ignore.allowed_recursive?(path, dir) && @only.allowed_recursive?(path, dir)
  end

  def all_allowed
    find_children(@root_trailing_slash) do |path, dir|
      next false unless @ignore.allowed_unrecursive?(path, dir)
      next false unless @only.allowed_unrecursive?(path, dir)
      next true if dir

      yield prepare_path(path)

      false
    end
  end

  private

  def prepare_path(path)
    @relative ? path.delete_prefix(@root_trailing_slash) : path
  end

  def find_children(path, &block) # rubocop:disable Metrics/MethodLength
    Dir.each_child(path) do |child|
      begin
        child = path + child
        stat = ::File.stat(child)
        next unless stat.readable?

        look_at_children = block.call child, stat.directory?
        find_children("#{child}/", &block) if look_at_children
      rescue Errno::ENOENT, Errno::EACCES, Errno::ENOTDIR, Errno::ELOOP, Errno::ENAMETOOLONG
        nil
      end
    end
  end
end
