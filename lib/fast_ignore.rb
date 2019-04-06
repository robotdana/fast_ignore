# frozen_string_literal: true

require_relative './fast_ignore/rule'
require_relative './fast_ignore/rule_list'
require_relative './fast_ignore/file_rule_list'
require_relative './fast_ignore/gitignore_rule_list'

require 'find'

class FastIgnore
  include Enumerable

  attr_reader :rules, :relative
  alias_method :relative?, :relative

  def initialize(rules: nil, files: nil, gitignore: true, relative: false)
    @relative = relative
    @rules = []
    @rules += FastIgnore::RuleList.new(*Array(rules)).to_a
    Array(files).reverse_each do |file|
      @rules += FastIgnore::FileRuleList.new(file).to_a
    end
    @rules += FastIgnore::GitignoreRuleList.new.to_a if gitignore
  end

  def enumerator
    Enumerator.new do |yielder|
      Find.find(root) do |path|
        dir = File.directory?(path)
        next if path == root
        next Find.prune unless pruned_allowed?(path, dir: dir)
        next if dir

        path = path.delete_prefix("#{root}/") if relative?

        yielder << path
      end
    end
  end

  def root
    @root ||= Dir.pwd
  end

  def allowed?(path, dir: File.directory?(path))
    return true if path == root

    allowed?(File.dirname(path), dir: true) && pruned_allowed?(path, dir: dir)
  end

  def pruned_allowed?(path, dir: File.directory?(path))
    path = path.delete_prefix(root)

    rules.each do |rule|
      return rule.negation? if rule.match?(path, dir)
    end
  end

  def each(&block)
    if block_given?
      enumerator.each(&block)
    else
      enumerator
    end
  end

  def files
    to_a
  end
end
