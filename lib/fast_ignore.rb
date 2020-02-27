# frozen_string_literal: true

require_relative './fast_ignore/rule_set_builder'
require_relative './fast_ignore/backports'

class FastIgnore
  include ::Enumerable

  # :nocov:
  if ::FastIgnore::Backports.ruby_version_less_than?(2, 5)
    require_relative 'fast_ignore/backports/delete_prefix_suffix'
    using ::FastIgnore::Backports::DeletePrefixSuffix

    require_relative 'fast_ignore/backports/dir_each_child'
    using ::FastIgnore::Backports::DirEachChild
  end
  # :nocov:

  def initialize( # rubocop:disable Metrics/ParameterLists, Metrics/MethodLength
    relative: false,
    root: ::Dir.pwd,
    ignore_rules: nil,
    ignore_files: nil,
    gitignore: :auto,
    include_rules: nil,
    include_files: nil,
    argv_rules: nil
  )
    @root = root.delete_suffix('/')
    @root_trailing_slash = "#{@root}/"

    @rule_sets = ::FastIgnore::RuleSetBuilder.from_args(
      root: @root,
      ignore_rules: ignore_rules,
      ignore_files: ignore_files,
      gitignore: gitignore,
      include_rules: include_rules,
      include_files: include_files,
      argv_rules: argv_rules
    )

    @relative = relative
  end

  def each(&block)
    if block_given?
      each_allowed(&block)
    else
      enum_for(:each_allowed)
    end
  end

  def allowed?(path)
    path = ::File.expand_path(path)
    stat = ::File.stat(path)
    dir = stat.directory?
    return false if dir

    @rule_sets.all? { |r| r.allowed_recursive?(path, dir) }
  rescue Errno::ENOENT, Errno::EACCES, Errno::ENOTDIR, Errno::ELOOP, Errno::ENAMETOOLONG
    false
  end

  private

  def prepare_path(path)
    @relative ? path.delete_prefix(@root_trailing_slash) : path
  end

  def each_allowed(path = @root_trailing_slash, &block) # rubocop:disable Metrics/MethodLength
    Dir.each_child(path) do |child|
      begin
        child = path + child
        stat = ::File.stat(child)

        dir = stat.directory?
        next unless @rule_sets.all? { |r| r.allowed_unrecursive?(child, dir) }

        if dir
          each_allowed("#{child}/", &block)
        else
          yield prepare_path(child)
        end
      rescue Errno::ENOENT, Errno::EACCES, Errno::ENOTDIR, Errno::ELOOP, Errno::ENAMETOOLONG
        nil
      end
    end
  end
end
