# frozen_string_literal: true

require_relative './find_ignore/rule'
require_relative './find_ignore/rule_list'
require_relative './find_ignore/file_rule_list'
require_relative './find_ignore/gitignore_rule_list'

require 'find'

class FindIgnore
  include Enumerable

  attr_reader :ignore, :rules

  def initialize(rules: nil, ignorefiles: nil, gitignore: true)
    @rules = []
    @rules += FindIgnore::RuleList.new(*Array(rules)).to_a
    Array(ignorefiles).reverse_each do |file|
      @rules += FindIgnore::FileRuleList.new(file).to_a
    end
    @rules += FindIgnore::GitignoreRuleList.new.to_a if gitignore
  end

  def enumerator
    Enumerator.new do |yielder|
      Find.find(root) do |path|
        dir = File.directory?(path)
        next if path == root
        next Find.prune unless pruned_allowed?(path, dir: dir)
        next if dir

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
    enumerator.each(&block)
  end

  def files(relative: false)
    if relative
      enumerator.map { |e| e.delete_prefix("#{root}/") }
    else
      enumerator.to_a
    end
  end
end
