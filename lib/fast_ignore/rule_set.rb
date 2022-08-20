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

    def match(candidate)
      matcher.match(candidate)
    end

    protected

    attr_reader :patterns

    private

    def matcher # rubocop:disable Metrics/MethodLength
      return @matcher if defined?(@matcher)

      matchers = @patterns.group_by(&:label_or_self).map do |_, patterns|
        if patterns.length == 1
          patterns.first.build
        else
          ::FastIgnore::Matchers::MatchOrDefault.new(
            ::FastIgnore::Matchers::LastMatch.build(patterns.flat_map(&:matchers)),
            patterns.first.default
          )
        end
      end

      @matcher = ::FastIgnore::Matchers::All.new(matchers)

      freeze

      @matcher
    end
  end
end
