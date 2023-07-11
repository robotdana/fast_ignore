# frozen_string_literal: true

require 'set'

class PathList
  class Matcher
    class ExactString
      class Set
        # @api private
        class CaseInsensitive < Set
          # @param (see ExactString::Set#initialize)
          def initialize(set, polarity)
            set = set.map(&:downcase)
            super(set, polarity)
          end

          # @param (see Matcher#match)
          # @return (see Matcher#match)
          def match(candidate)
            puts "#{__FILE__}:#{__LINE__}, @set: #{@set}"
            puts "#{__FILE__}:#{__LINE__}, candidate.full_path_downcase: #{candidate.full_path_downcase}"
            @polarity if @set.include?(candidate.full_path_downcase)
          end
        end
      end
    end
  end
end
