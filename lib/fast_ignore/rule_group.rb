# frozen_string_literal: true

class FastIgnore
  class RuleGroup
    def initialize(matchers, allow)
      @matchers = Array(matchers).compact
      @allow = allow
      @allowed_recursive = { ::FastIgnore::RootCandidate::RootDir => true }
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

    def <<(matcher)
      (@matchers += matcher) unless !matcher || matcher.empty?
    end

    def allowed_recursive?(root_candidate)
      @allowed_recursive.fetch(root_candidate) do
        @allowed_recursive[root_candidate] =
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
