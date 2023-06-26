# frozen_string_literal: true

class PathList
  module Matchers
    class ExactStringList
      class Some < ExactStringList
        def self.build(array, polarity)
          ExactStringList.build(array, polarity)
        end

        def initialize(array, polarity) # rubocop:disable Lint/MissingSuper
          @polarity = polarity
          @array = array
          @weight = 1
        end

        def match(candidate)
          return @polarity if @array.include?(candidate.full_path_downcase)
        end
      end
    end
  end
end
