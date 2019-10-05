# frozen_string_literal: true

require_relative './fast_ignore/rule'
require_relative './fast_ignore/rule_list'
require_relative './fast_ignore/file_rule_list'
require_relative './fast_ignore/gitignore_rule_list'

require 'find'

class FastIgnore # rubocop:disable Metrics/ClassLength
  include ::Enumerable

  unless ::RUBY_VERSION >= '2.5'
    require_relative 'fast_ignore/backports/delete_prefix_suffix'
    using ::FastIgnore::Backports::DeletePrefixSuffix
  end

  attr_reader :relative
  alias_method :relative?, :relative
  attr_reader :root

  def initialize( # rubocop:disable Metrics/ParameterLists
    relative: false,
    root: ::Dir.pwd,
    rules: nil,
    ignore_rules: rules,
    files: nil,
    ignore_files: files,
    gitignore: ::File.join(root, '.gitignore'),
    include_rules: nil,
    include_files: nil
  )
    if rules || files
      warn <<~WARNING
        \e[33mFastIgnore.new `:rules` and `:files` keyword arguments are deprecated.
        Please use `:ignore_rules` and `:ignore_files` instead.\e[0m
      WARNING
    end
    prepare_include_rules(include_rules, include_files)
    prepare_ignore_rules(ignore_rules, ignore_files, gitignore)
    @relative = relative
    @root = root
  end

  def prepare_ignore_rules(ignore_rules, ignore_files, gitignore)
    @ignore_rules += ::FastIgnore::RuleList.new(*Array(ignore_rules)).to_a
    Array(ignore_files).reverse_each do |file|
      @ignore_rules += ::FastIgnore::FileRuleList.new(file).to_a
    end

    @ignore_rules += ::FastIgnore::GitignoreRuleList.new(gitignore).to_a if gitignore
  end

  def prepare_include_rules(include_rules, include_files)
    include_rules = ::FastIgnore::RuleList.new(*Array(include_rules), expand_path: true).to_a
    Array(include_files).reverse_each do |file|
      include_rules += ::FastIgnore::FileRuleList.new(file).to_a
    end

    @include_rules = include_rules.reject(&:negation?)
    @ignore_rules = include_rules.select(&:negation?).each(&:invert)
  end

  def each(&block)
    if block_given?
      enumerator.each(&block)
    else
      enumerator
    end
  end

  def allowed?(path)
    allowed_expanded?(::File.expand_path(path))
  end

  private

  def enumerator
    if !@include_rules.empty? && @include_rules.all?(&:globbable?)
      glob_enumerator
    else
      find_enumerator
    end
  end

  def allowed_expanded?(path, dir = ::File.directory?(path))
    not_excluded_recursive?(path, dir) && not_ignored_recursive?(path, dir)
  end

  def glob_enumerator # rubocop:disable Metrics/MethodLength
    seen = {}
    ::Enumerator.new do |yielder|
      ::Dir.glob(@include_rules.flat_map(&:glob_pattern), ::FastIgnore::Rule::FNMATCH_OPTIONS) do |path|
        next if seen[path]

        seen[path] = true
        next if ::File.directory?(path)
        next unless ::File.readable?(path)
        next unless not_ignored_recursive?(path, false)

        path = path.delete_prefix("#{root}/") if @relative

        yielder << path
      end
    end
  end

  def find_enumerator # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
    ::Enumerator.new do |yielder|
      ::Find.find(root) do |path|
        next if path == root
        next unless ::File.readable?(path)

        dir = ::File.directory?(path)
        next ::Find.prune unless not_ignored?(path, dir)
        next unless not_excluded_recursive?(path, dir)
        next if dir

        path = path.delete_prefix("#{root}/") if @relative

        yielder << path
      end
    end
  end

  def not_ignored_recursive?(path, dir = ::File.directory?(path))
    @not_ignored ||= {}
    @not_ignored.fetch(path) do
      @not_ignored[path] = if path == root
        true
      else
        not_ignored_recursive?(::File.dirname(path), true) && not_ignored?(path, dir)
      end
    end
  end

  def not_excluded_recursive?(path, dir = ::File.directory?(path))
    return true if @include_rules.empty?

    @not_excluded ||= {}
    @not_excluded.fetch(path) do
      @not_excluded[path] = if path == root
        false
      else
        not_excluded_recursive?(::File.dirname(path), true) || not_excluded?(path, dir)
      end
    end
  end

  def non_dir_ignore_rules
    @non_dir_ignore_rules ||= @ignore_rules.reject(&:dir_only?)
  end

  def non_dir_include_rules
    @non_dir_include_rules ||= @include_rules.reject(&:dir_only?)
  end

  def not_excluded?(path, dir)
    return true if @include_rules.empty?

    (dir ? @include_rules : non_dir_include_rules).find do |rule|
      rule.match?(path)
    end
  end

  def not_ignored?(path, dir)
    (dir ? @ignore_rules : non_dir_ignore_rules).each do |rule|
      return rule.negation? if rule.match?(path)
    end

    true
  end
end
