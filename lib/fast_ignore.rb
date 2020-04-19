# frozen_string_literal: true

require_relative './fast_ignore/backports'

require_relative './fast_ignore/rule_parser'
require_relative './fast_ignore/rule_set_builder'
require_relative './fast_ignore/rule_set'
require_relative './fast_ignore/rule'

class FastIgnore # rubocop:disable Metrics/ClassLength
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

    rule_sets = ::FastIgnore::RuleSetBuilder.from_args(
      root: @root_trailing_slash,
      ignore_rules: ignore_rules,
      ignore_files: ignore_files,
      gitignore: gitignore,
      include_rules: include_rules,
      include_files: include_files,
      argv_rules: argv_rules
    )

    @include_rule_sets, @ignore_rule_sets = rule_sets.partition(&:allow?)
    @has_include_rule_sets = !@include_rule_sets.empty?
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

  def allowed?(path) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    path = ::File.expand_path(path)
    return false if path.start_with?('/') && !path.start_with?(@root_trailing_slash)

    dir = ::File.stat(path).directory? # equivalent to directory? and exist?
    path = path.delete_prefix(@root_trailing_slash)

    return false if dir
    return false unless @ignore_rule_sets.all? { |r| r.allowed_recursive?(path, dir) }
    return @include_rule_sets.all? { |r| r.allowed_recursive?(path, dir) } unless @shebang_pattern

    (@has_include_rule_sets &&
      @include_rule_sets.all? { |r| r.allowed_unrecursive?(path, false) }) ||
      match_shebang?(path, ::File.basename(path))
  rescue Errno::ENOENT, Errno::EACCES, Errno::ENOTDIR, Errno::ELOOP, Errno::ENAMETOOLONG
    false
  end

  private

  def prepare_path(path)
    @relative ? path : @root_trailing_slash + path
  end

  def each_allowed(path = nil, &block) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    Dir.each_child(path || '.') do |basename|
      begin
        child = path.to_s + basename
        dir = ::File.stat(child).directory? # equivalent to directory? and exist?

        next unless @ignore_rule_sets.all? { |r| r.allowed_unrecursive?(child, dir) }

        if dir
          next unless @shebang_pattern || @include_rule_sets.all? { |r| r.allowed_unrecursive?(child, dir) }

          each_allowed("#{child}/", &block)
        else
          if @shebang_pattern
            unless (@has_include_rule_sets &&
                @include_rule_sets.all? { |r| r.allowed_unrecursive?(child, dir) }) ||
                match_shebang?(child, basename)
              next
            end
          else
            next unless @include_rule_sets.all? { |r| r.allowed_unrecursive?(child, dir) }
          end

          yield prepare_path(child)
        end
      rescue Errno::ENOENT, Errno::EACCES, Errno::ENOTDIR, Errno::ELOOP, Errno::ENAMETOOLONG
        nil
      end
    end
  end

  def match_shebang?(path, basename)
    return false if basename.include?('.')

    begin
      f = ::File.new(path)
      # i can't imagine a shebang being longer than 20 characters, lets multiply that by 10 just in case.
      fragment = f.sysread(256)
      f.close
    rescue SystemCallError, EOFError
      return false
    end

    @shebang_pattern.match?(fragment)
  end

  def prepare_shebang_pattern(rules)
    return if !rules || (rules = Array(rules)).empty?

    rules = rules.flat_map { |s| s.to_s.split("\n") }
    rules_re = rules.map { |s| Regexp.escape(s.to_s) }.join('|')

    /\A#!.*\b(?:#{rules_re})\b/.freeze
  end
end
