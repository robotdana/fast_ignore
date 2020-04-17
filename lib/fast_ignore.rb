# frozen_string_literal: true

require_relative './fast_ignore/backports'

require_relative './fast_ignore/rule_parser'
require_relative './fast_ignore/rule_set_builder'
require_relative './fast_ignore/rule_set'
require_relative './fast_ignore/rule'

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
    include_shebangs: nil,
    argv_rules: nil
  )
    @root = root.delete_suffix('/')
    @root_trailing_slash = "#{@root}/"
    @shebang_pattern = prepare_shebang_pattern(include_shebangs)

    @rule_sets = ::FastIgnore::RuleSetBuilder.from_args(
      root: @root,
      ignore_rules: ignore_rules,
      ignore_files: ignore_files,
      gitignore: gitignore,
      include_rules: include_rules,
      include_files: include_files,
      argv_rules: argv_rules,
      and_no_ext: @shebang_pattern
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

    basename = ::File.basename(path)

    @rule_sets.all? { |r| r.allowed_recursive?(path, dir, basename) } && match_shebang?(path, basename)
  rescue Errno::ENOENT, Errno::EACCES, Errno::ENOTDIR, Errno::ELOOP, Errno::ENAMETOOLONG
    false
  end

  private

  def prepare_path(path)
    @relative ? path.delete_prefix(@root_trailing_slash) : path
  end

  def each_allowed(path = @root_trailing_slash, &block) # rubocop:disable Metrics/MethodLength
    Dir.each_child(path) do |basename|
      begin
        child = path + basename
        stat = ::File.stat(child)

        dir = stat.directory?

        if dir
          next unless @rule_sets.all? { |r| r.allowed_unrecursive?(child, dir, nil) }

          each_allowed("#{child}/", &block)
        else
          unless @rule_sets.all? { |r| r.allowed_unrecursive?(child, dir, basename) } && match_shebang?(child, basename)
            next
          end

          yield prepare_path(child)
        end
      rescue Errno::ENOENT, Errno::EACCES, Errno::ENOTDIR, Errno::ELOOP, Errno::ENAMETOOLONG
        nil
      end
    end
  end

  def match_shebang?(path, basename)
    return true unless @shebang_pattern
    return true if basename.include?('.')

    begin
      f = ::File.new(path)
      # i can't imagine a shebang being longer than 20 characters, lets multiply that by 10 just in case.
      fragment = f.sysread(256)
      f.close
    rescue SystemCallError, EOFError
      return
    end

    @shebang_pattern.match?(fragment)
  end

  def prepare_shebang_pattern(rules)
    return if !rules || (rules = Array(rules)).empty?

    /\A#!.*\b(?:#{rules.flat_map { |s| s.to_s.split("\n") }.map { |s| Regexp.escape(s.to_s) }.join('|')})\b/.freeze
  end
end
