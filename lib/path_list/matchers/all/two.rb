# frozen_string_literal: true

class PathList
  module Matchers
    class All
      class Two < All
        def self.build(matchers)
          All.build(matchers)
        end

        attr_reader :polarity
        attr_reader :weight

        def initialize(matcher_a, matcher_b) # rubocop:disable Lint/MissingSuper
          @matcher_a = matcher_a
          @matcher_b = matcher_b
          @weight = calculate_weight
          @polarity = calculate_polarity

          freeze
        end

        def squashable_with?(_)
          false
        end

        def match(candidate)
          case (result = @matcher_a.match(candidate))
          when :allow, nil
            case (result_b = @matcher_b.match(candidate))
            when :allow, nil then result_b && result
            when :ignore then :ignore
            end
          when :ignore then :ignore
          end
        end

        def inspect
          "#{self.class}.new(\n#{matchers.map(&:inspect).join(",\n").gsub(/^/, '  ')}\n)"
        end

        def matchers
          [@matcher_a, @matcher_b]
        end

        private

        def calculate_weight
          (@matcher_a.weight + @matcher_b.weight) / 2.0
        end

        def calculate_polarity
          @matcher_a.polarity == @matcher_b.polarity ? @matcher_a.polarity : :mixed
        end
      end
    end
  end
end
