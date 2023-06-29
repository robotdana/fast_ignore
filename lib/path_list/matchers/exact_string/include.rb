# frozen_string_literal: true

class PathList
  module Matchers
    class ExactString
      class Include < ExactString
        def self.build(array, polarity)
          ExactString.build(array, polarity)
        end

        def initialize(array, polarity) # rubocop:disable Lint/MissingSuper
          @polarity = polarity
          @array = array
          @weight = (array.length / 20.0) + 1
        end

        def inspect
          "#{self.class}.new([\n  #{@array.map(&:inspect).join(",\n  ")}\n], #{@polarity.inspect})"
        end

        attr_reader :array

        def match(candidate)
          return @polarity if @array.include?(candidate.full_path_downcase)
        end
      end
    end
  end
end
