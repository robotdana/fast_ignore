# frozen_string_literal: true

require 'set'

class PathList
  class Matcher
    class ExactString
      # @api private
      class Set < ExactString
        Autoloader.autoload(self)

        # @param (see ExactString.build)
        # @return (see ExactString.build)
        def self.build(set, polarity)
          ExactString.build(set, polarity)
        end

        # @param (see .build)
        # @return (see .build)
        def initialize(set, polarity) # rubocop:disable Lint/MissingSuper
          @set = set.to_set
          @weight = (set.length / 100.0) + 1
          @polarity = polarity

          freeze
        end

        # @param (see Matcher#match)
        # @return (see Matcher#match)
        def match(candidate)
          @polarity if @set.include?(candidate.full_path)
        end

        # @return (see Matcher#inspect)
        def inspect
          "#{self.class}.new([#{@set.to_a.sort.map(&:inspect).join(', ')}], #{@polarity.inspect})"
        end

        # @return set [Set]
        attr_reader :set
      end
    end
  end
end
