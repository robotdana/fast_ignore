# frozen_string_literal: true

require_relative './fast_ignore/rule_set'
require 'find'

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
    @ignore = ::FastIgnore::RuleSet.new
    only = ::FastIgnore::RuleSet.new
    only.add_files(include_files)
    only.add_rules(include_rules, root: root, expand_path: true)
    new_ignore_rules = only.rules.flat_map do |rule|
      dirs = rule.rule.dup.delete_prefix("#{root}/").split('/')
      dirs.flat_map.with_index do |dir, index|
        if dir == dirs.last
          dir = "#{root}/#{dirs[0..index].join('/')}"
          [
            ::FastIgnore::Rule.new(dir, rule.dir_only?, !rule.negation?, rule.anchored?),
            ::FastIgnore::Rule.new("#{dir}/**/*", false, !rule.negation?, rule.anchored?)
          ]
        else
          dir = "#{root}/#{dirs[0..index].join('/')}"
          ::FastIgnore::Rule.new(dir, true, !rule.negation?, rule.anchored?)
        end
      end
    end
    unless new_ignore_rules.empty?
      @ignore.add_rules('*')
      unless new_ignore_rules.all?(&:anchored?)
        @ignore.add_rules('!*/')
      end
      @ignore.rules.concat(new_ignore_rules)
      @ignore.send(:non_dir_only_rules).concat(new_ignore_rules.reject(&:dir_only?))
    end
    @ignore.add_rules('.git')
    @ignore.add_files(gitignore) if gitignore && ::File.exist?(gitignore)
    @ignore.add_files(ignore_files)
    @ignore.add_rules(ignore_rules, root: root)
    @ignore.add_rules('.gitkeep')
    @relative = relative
    @root = root
  end

  def each_allowed(&block)
    find_allowed(&block)
  end

  def allowed_recursive?(path, dir = ::File.directory?(path))
    @allowed_recursive ||= {}
    @allowed_recursive.fetch(path) do
      @allowed_recursive[path] = @ignore.allowed_recursive?(path, dir)
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

      yield prepare_path(path)
    end
  end

  # rustify
  def prepare_path(path)
    @relative ? path.delete_prefix("#{root}/") : path
  end
end
