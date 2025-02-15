# frozen_string_literal: true

class PathList
  class Matcher
    # @api private
    class All < List
      Autoloader.autoload(self)

      # @param (see List.compress)
      # @return (see List.compress)
      def self.compress(matcher_list)
        matchers = super - [Matcher::Allow]
        return [Matcher::Allow] if matchers.empty?
        return [Matcher::Ignore] if matchers.include?(Matcher::Ignore)

        matchers.uniq!
        matchers.sort_by!(&:weight)
        matchers.freeze
      end

      # @param (see Matcher#match)
      # @return (see Matcher#match)
      def match(candidate)
        default = :allow

        @matchers.each do |m|
          if (result = m.match(candidate)) == :ignore
            return :ignore
          elsif result
            nil
          else
            default = nil
          end
        end

        default
      end

      # @return (see Matcher#polarity)
      def polarity
        :mixed
      end

      private

      def calculate_weight
        super + 1
      end
    end
  end
end
