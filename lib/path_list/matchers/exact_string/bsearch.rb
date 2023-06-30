# frozen_string_literal: true

class PathList
  module Matchers
    class ExactString
      class Bsearch < ExactString
        def self.build(array, polarity)
          ExactString.build(array, polarity)
        end

        def initialize(array, polarity) # rubocop:disable Lint/MissingSuper
          @polarity = polarity
          @array = array
          @weight = (array.length / 100.0) + 1

          freeze
        end

        def match(candidate)
          full_path = candidate.full_path_downcase

          return @polarity if @array.bsearch { |element| full_path <=> element }
        end

        def inspect
          "#{self.class}.new([\n  #{@array.map(&:inspect).join(",\n  ")}\n], #{@polarity.inspect})"
        end

        attr_reader :array
      end
    end
  end
end
