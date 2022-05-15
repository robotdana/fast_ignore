# frozen_string_literal: true

class FastIgnore
  class RuleSet
    def initialize(new_item = nil, from: nil)
      @patterns = [*from&.patterns, *new_item].freeze
    end

    def new(new_item = nil)
      self.class.new(new_item, from: self)
    end

    def build # rubocop:disable Metrics/MethodLength
      @matchers = begin
        matchers = @patterns.uniq.group_by(&:label_or_self).map do |_k, patterns|
          if patterns.length == 1
            patterns.first.build
          else
            ::FastIgnore::Matchers::RuleGroup.new(
              patterns.flat_map(&:matchers),
              patterns.first.allow
            )
          end
        end

        matchers.reject!(&:empty?)
        matchers.sort_by!(&:weight)
        matchers.freeze
      end
    end

    def allowed_recursive?(candidate)
      return true unless candidate.parent

      allowed_recursive?(candidate.parent) &&
        allowed_unrecursive?(candidate)
    end

    def allowed_unrecursive?(candidate)
      @matchers.all? { |r| r.match?(candidate) }
    end

    protected

    attr_reader :patterns
  end
end
