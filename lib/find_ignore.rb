# frozen_string_literal: true

require_relative './find_ignore/gitignore_rule_list'

require 'find'

class FindIgnore
  include Enumerable

  attr_reader :ignore, :rules

  def initialize(gitignore: true)
    @rules = []
    @rules = FindIgnore::GitignoreRuleList.new if gitignore
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

    !rules.reduce(false) do |ignored, rule|
      if rule.negation?
        ignored = false if ignored && rule.match?(path, dir)
      else
        ignored = true if !ignored && rule.match?(path, dir)
      end
      ignored
    end
  end

  def each(&block)
    enumerator.each(&block)
  end

  def files(relative: false)
    if relative
      enumerator.map { |e| e.delete_prefix("#{Dir.pwd}/") }
    else
      enumerator.to_a
    end
  end
end
