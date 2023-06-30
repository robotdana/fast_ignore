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

          freeze
        end

        def match(candidate)
          return @polarity if @array.include?(candidate.full_path_downcase)
        end

        def inspect
          array_inspect = if @array.sum(&:length) > 40
            "[\n  #{@array.map(&:inspect).join(",\n  ")}\n]"
          else
            "[#{@array.map(&:inspect).join(', ')}]"
          end
          "#{self.class}.new(#{array_inspect}, #{@polarity.inspect})"
        end

        attr_reader :array
      end
    end
  end
end
