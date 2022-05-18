# frozen_string_literal: true

class FastIgnore
  class RuleSet
    def self.new_with_pattern(pattern)
      new([pattern])
    end

    def initialize(patterns = [])
      @patterns = patterns.freeze
    end

    def new_with_pattern(pattern)
      return self if @patterns.include?(pattern)

      self.class.new(@patterns.dup.push(pattern))
    end

    def build # rubocop:disable Metrics/MethodLength
      return @matchers if defined?(@matchers)

      @matchers = @patterns.group_by(&:label_or_self).map do |_, patterns|
        if patterns.length == 1
          patterns.first.build
        else
          ::FastIgnore::Matchers::MatchOrDefault.new(
            ::FastIgnore::Matchers::LastMatch.new(patterns.flat_map(&:matchers)),
            patterns.first.default
          )
        end
      end

      @matchers.reject!(&:empty?)
      @matchers.sort_by!(&:weight)
      @matchers.freeze

      freeze

      @matchers
    end

    def allowed_recursive?(candidate)
      return true unless candidate.parent

      allowed_recursive?(candidate.parent) &&
        allowed_unrecursive?(candidate)
    end

    def allowed_unrecursive?(candidate)
      @matchers.all? { |r| r.match?(candidate) == :allow }
    end

    protected

    attr_reader :patterns
  end
end
