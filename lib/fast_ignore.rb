# frozen_string_literal: true

require_relative './fast_ignore/backports'

require_relative './fast_ignore/rule_parser'
require_relative './fast_ignore/rule_set_builder'
require_relative './fast_ignore/rule_set'
require_relative './fast_ignore/rule'

class FastIgnore
  class Error < StandardError; end

  include ::Enumerable

  # :nocov:
  if ::FastIgnore::Backports.ruby_version_less_than?(2, 5)
    require_relative 'fast_ignore/backports/delete_prefix_suffix'
    using ::FastIgnore::Backports::DeletePrefixSuffix

    require_relative 'fast_ignore/backports/dir_each_child'
    using ::FastIgnore::Backports::DirEachChild
  end
  # :nocov:

  def initialize( # rubocop:disable Metrics/MethodLength
    relative: false,
    root: nil,
    include_shebangs: nil,
    **rule_set_builder_args
  )
    # :nocov:
    if include_shebangs && !Array(include_shebangs).empty?

      warn <<~WARNING
        Removed FastIgnore `include_shebangs:` argument.
        It will be ignored. Please replace with the include_rules: in the shebang format
        https://github.com/robotdana/fast_ignore#shebang-rules
      WARNING
    end
    # :nocov:

    root = root ? File.expand_path(root, ::Dir.pwd) : ::Dir.pwd
    @root = "#{root}/"

    @rule_sets = ::FastIgnore::RuleSetBuilder.from_args(root: @root, **rule_set_builder_args)
    @relative = relative

    freeze
  end

  def each(&block)
    if block_given?
      each_allowed(&block)
    else
      enum_for(:each_allowed)
    end
  end

  def allowed?(path)
    full_path = ::File.expand_path(path, @root)
    return false unless full_path.start_with?(@root)

    dir = ::File.stat(full_path).directory? # shortcut for exists? && directory?
    return false if dir

    relative_path = full_path.delete_prefix(@root)
    filename = ::File.basename(relative_path)

    @rule_sets.all? { |r| r.allowed_recursive?(relative_path, dir, filename) }
  rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENOTDIR, ::Errno::ELOOP, ::Errno::ENAMETOOLONG
    false
  end

  private

  def each_allowed(full_path = @root, relative_path = '', &block) # rubocop:disable Metrics/MethodLength
    ::Dir.each_child(full_path) do |filename|
      begin
        full_child = full_path + filename
        relative_child = relative_path + filename
        dir = ::File.directory?(full_child)

        next unless @rule_sets.all? { |r| r.allowed_unrecursive?(relative_child, dir, filename) }

        if dir
          each_allowed("#{full_child}/", "#{relative_child}/", &block)
        else
          yield(@relative ? relative_child : full_child)
        end
      rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENOTDIR, ::Errno::ELOOP, ::Errno::ENAMETOOLONG
        nil
      end
    end
  end
end
