# frozen_string_literal: true

class FastIgnore
  class RuleGroup
    def initialize(patterns, allow)
      @matchers = Array(patterns).flat_map { |x| x.build_matchers(include: allow) }.compact
      @allow = allow
      @allowed_recursive = { '/' => true }
    end

    def empty?
      @matchers.empty? || @matchers.all?(&:empty?)
    end

    def weight
      @matchers.sum(&:weight)
    end

    def freeze
      @matchers.freeze

      super
    end

    def <<(patterns)
      matcher = patterns.build_matchers(include: @allow)

      @matchers += matcher unless !matcher || matcher.empty?
    end

    def allowed_recursive?(root_candidate)
      @allowed_recursive.fetch(root_candidate.full_path) do
        @allowed_recursive[root_candidate.full_path] =
          allowed_recursive?(root_candidate.parent) &&
          allowed_unrecursive?(root_candidate)
      end
    end

    def allowed_unrecursive?(root_candidate)
      @matchers.reverse_each do |matcher|
        val = matcher.match?(root_candidate)
        return val == :allow if val
      end

      not @allow
    end
  end
end
