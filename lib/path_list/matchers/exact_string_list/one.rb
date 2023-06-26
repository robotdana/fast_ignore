# frozen_string_literal: true

class PathList
  module Matchers
    class ExactStringList
      class One < ExactStringList
        def self.build(array, polarity)
          ExactStringList.build(array, polarity)
        end

        def initialize(array, polarity) # rubocop:disable Lint/MissingSuper
          @polarity = polarity
          @item = array.first
          @array = array
          @weight = 1
        end

        def match(candidate)
          return @polarity if @item == candidate.full_path_downcase
        end
      end
    end
  end
end
