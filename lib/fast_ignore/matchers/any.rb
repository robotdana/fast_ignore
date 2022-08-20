# frozen_string_literal: true

class FastIgnore
  module Matchers
    class Any < List
      def match(candidate)
        ignore = false

        @matchers.each do |m|
          case m.match(candidate)
          when :allow then return :allow
          # :nocov:
          when :ignore then ignore = true
            # :nocov:
          end
        end

        # :nocov:
        :ignore if ignore
        # :nocov:
      end
    end
  end
end
