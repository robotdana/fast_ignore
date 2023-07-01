# frozen_string_literal: true

require 'set'

class PathList
  module Matchers
    class ExactString
      class Set < ExactString
        def self.build(set, polarity)
          ExactString.build(set, polarity)
        end

        def initialize(set, polarity) # rubocop:disable Lint/MissingSuper
          @set = set.to_set
          @weight = (set.length / 100.0) + 1
          @polarity = polarity

          freeze
        end

        def match(candidate)
          @polarity if @set.include?(candidate.full_path_downcase)
        end

        def inspect
          "#{self.class}.new([#{@set.map(&:inspect).join(', ')}], #{@polarity.inspect})"
        end

        attr_reader :set

        def ==(other)
          other.instance_of?(self.class) &&
            @polarity == other.polarity &&
            @set == other.set
        end
      end
    end
  end
end
