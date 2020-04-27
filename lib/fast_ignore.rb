# frozen_string_literal: true

require_relative './fast_ignore/backports'

require_relative './fast_ignore/rule_set_builder'
require_relative './fast_ignore/rule_builder'
require_relative './fast_ignore/rule_set'
require_relative './fast_ignore/rule'
require_relative './fast_ignore/shebang_rule'
require_relative './fast_ignore/fn_match_to_re'

class FastIgnore
  class Error < StandardError; end

  include ::Enumerable

  # :nocov:
  using ::FastIgnore::Backports::DeletePrefixSuffix if defined?(::FastIgnore::Backports::DeletePrefixSuffix)
  using ::FastIgnore::Backports::DirEachChild if defined?(::FastIgnore::Backports::DirEachChild)
  # :nocov:

  def initialize(relative: false, root: nil, follow_symlinks: false, **rule_set_builder_args)
    @relative = relative
    @follow_symlinks = follow_symlinks
    @root = "#{::File.expand_path(root.to_s, Dir.pwd)}/"
    @rule_sets = ::FastIgnore::RuleSetBuilder.build(root: @root, **rule_set_builder_args)

    freeze
  end

  def each(&block)
    return enum_for(:each) unless block_given?

    dir_pwd = Dir.pwd
    root_from_pwd = @root.start_with?(dir_pwd) ? ".#{@root.delete_prefix(dir_pwd)}" : @root

    each_recursive(root_from_pwd, '', &block)
  end

  def directory?(path)
    if @follow_symlinks
      ::File.stat(path).directory?
    else
      ::File.lstat(path).directory?
    end
  end

  def allowed?(path)
    full_path = ::File.expand_path(path, @root)
    return false unless full_path.start_with?(@root)
    return false if directory?(full_path)

    relative_path = full_path.delete_prefix(@root)
    filename = ::File.basename(relative_path)

    @rule_sets.all? { |r| r.allowed_recursive?(relative_path, false, full_path, filename) }
  rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENOTDIR, ::Errno::ELOOP, ::Errno::ENAMETOOLONG
    false
  end
  alias_method :===, :allowed?

  private

  def each_recursive(parent_full_path, parent_relative_path, &block) # rubocop:disable Metrics/MethodLength
    ::Dir.each_child(parent_full_path) do |filename|
      begin
        full_path = parent_full_path + filename
        relative_path = parent_relative_path + filename
        dir = directory?(full_path)

        next unless @rule_sets.all? { |r| r.allowed_unrecursive?(relative_path, dir, full_path, filename) }

        if dir
          each_recursive(full_path + '/', relative_path + '/', &block)
        else
          yield(@relative ? relative_path : @root + relative_path)
        end
      rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENOTDIR, ::Errno::ELOOP, ::Errno::ENAMETOOLONG
        nil
      end
    end
  end
end
