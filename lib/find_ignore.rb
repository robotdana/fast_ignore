# frozen_string_literal: true

require 'find_ignore/version'
require 'find_ignore/rule'

require 'find'
class FindIgnore
  include Enumerable

  attr_reader :ignore

  def initialize(ignore: File.join(Dir.pwd, '.gitignore'))
    @ignore = ignore
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
    @root ||= ignore && File.dirname(ignore) || Dir.pwd
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

  def rules
    @rules ||= begin
      IO.foreach(ignore).map do |rule|
        FindIgnore::Rule.new(rule)
      end.reject(&:skip?)
    rescue Errno::ENOENT
      []
    end
  end

  def each(&block)
    enumerator.each(&block)
  end

  def files
    enumerator.to_a
  end
end
