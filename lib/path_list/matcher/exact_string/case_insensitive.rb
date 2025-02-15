# frozen_string_literal: true

require 'set'

class PathList
  class Matcher
    class ExactString
      # @api private
      class CaseInsensitive < ExactString
        # @param (see ExactString.build)
        # @return (see ExactString.build)
        def self.build(set, polarity)
          ExactString.build(set, polarity)
        end

        # @param (see ExactString#initialize)
        def initialize(item, polarity)
          item = item.downcase
          super
        end

        # @param (see Matcher#match)
        # @return (see Matcher#match)
        def match(candidate)
          @polarity if @item == candidate.full_path_downcase
        end
      end
    end
  end
end
