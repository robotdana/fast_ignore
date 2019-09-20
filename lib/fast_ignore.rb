# frozen_string_literal: true

require_relative './fast_ignore/delete_prefix_suffix'
require_relative './fast_ignore/rule'
require_relative './fast_ignore/rule_list'
require_relative './fast_ignore/file_rule_list'
require_relative './fast_ignore/gitignore_rule_list'

require 'find'

class FastIgnore
  include Enumerable
  using DeletePrefixSuffix unless RUBY_VERSION >= '2.5'

  attr_reader :rules
  attr_reader :relative
  alias_method :relative?, :relative
  attr_reader :root

  def initialize(
    rules: nil,
    files: nil,
    relative: false,
    root: Dir.pwd,
    gitignore: File.join(root, '.gitignore')
  )
    @rules = []
    @rules += FastIgnore::RuleList.new(*Array(rules)).to_a
    Array(files).reverse_each do |file|
      @rules += FastIgnore::FileRuleList.new(file).to_a
    end
    @rules += FastIgnore::GitignoreRuleList.new(gitignore).to_a if gitignore
    @relative = relative
    @root = root
  end

  def each(&block)
    if block_given?
      enumerator.each(&block)
    else
      enumerator
    end
  end

  def allowed?(path, dir: File.directory?(path))
    return true if path == root

    allowed?(File.dirname(path), dir: true) && pruned_allowed?(path, dir: dir)
  end

  private

  def enumerator # rubocop:disable Metrics/MethodLength
    Enumerator.new do |yielder|
      Find.find(root) do |path|
        dir = File.directory?(path)
        next if path == root
        next unless File.readable?(path)
        next Find.prune unless pruned_allowed?(path, dir: dir)
        next if dir

        path = path.delete_prefix("#{root}/") if relative?

        yielder << path
      end
    end
  end

  def pruned_allowed?(path, dir: File.directory?(path))
    rules.each do |rule|
      return rule.negation? if rule.match?(path, dir: dir)
    end
  end
end
