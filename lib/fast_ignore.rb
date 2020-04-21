# frozen_string_literal: true

require_relative './fast_ignore/backports'

require_relative './fast_ignore/rule_set_builder'
require_relative './fast_ignore/rule_builder'
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

  def initialize(relative: false, root: nil, **rule_set_builder_args)
    @relative = relative
    @root = "#{File.expand_path(root || '')}/"
    @rule_sets = ::FastIgnore::RuleSetBuilder.build(root: @root, **rule_set_builder_args)

    freeze
  end

  def each(&block)
    return enum_for(:each) unless block_given?

    each_recursive(@root, '', &block)
  end

  def allowed?(path)
    full_path = ::File.expand_path(path, @root)
    return false unless full_path.start_with?(@root)
    return false if ::File.lstat(full_path).directory?

    relative_path = full_path.delete_prefix(@root)
    filename = ::File.basename(relative_path)

    @rule_sets.all? { |r| r.allowed_recursive?(relative_path, false, filename) }
  rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENOTDIR, ::Errno::ELOOP, ::Errno::ENAMETOOLONG
    false
  end

  private

  def each_recursive(parent_full_path, parent_relative_path, &block) # rubocop:disable Metrics/MethodLength
    ::Dir.each_child(parent_full_path) do |filename|
      begin
        full_path = parent_full_path + filename
        relative_path = parent_relative_path + filename
        dir = ::File.lstat(full_path).directory?

        next unless @rule_sets.all? { |r| r.allowed_unrecursive?(relative_path, dir, filename) }

        if dir
          each_recursive(full_path + '/', relative_path + '/', &block)
        else
          yield(@relative ? relative_path : full_path)
        end
      rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENOTDIR, ::Errno::ELOOP, ::Errno::ENAMETOOLONG
        nil
      end
    end
  end
end
