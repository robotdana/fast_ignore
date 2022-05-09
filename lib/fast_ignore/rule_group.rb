# frozen_string_literal: true

class FastIgnore
  class RuleGroup
    def initialize(patterns, allow)
      @patterns = Array(patterns)
      @allow = allow
      @allowed_recursive = { ::FastIgnore::Candidate.root.key => true }.compare_by_identity
    end

    def append(new_patterns)
      new_patterns = Array(new_patterns)
      @patterns.concat(new_patterns)

      new_matchers = new_patterns.flat_map { |x| x.build_matchers(allow: @allow) }.compact
      return if new_matchers.empty?

      @matchers.concat(new_matchers)
    end

    def build
      @matchers = @patterns.flat_map { |x| x.build_matchers(allow: @allow) }.compact

      freeze
    end

    def empty?
      @matchers.empty? || @matchers.all?(&:empty?)
    end

    def weight
      @matchers.sum(&:weight)
    end

    def allowed_recursive?(candidate)
      @allowed_recursive.fetch(candidate.key) do
        @allowed_recursive[candidate.key] =
          allowed_recursive?(candidate.parent) &&
          allowed_unrecursive?(candidate)
      end
    end

    def allowed_unrecursive?(candidate)
      @matchers.reverse_each do |matcher|
        val = matcher.match?(candidate)
        return val == :allow if val
      end

      not @allow
    end
  end
end
