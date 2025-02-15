# frozen_string_literal: true

class PathList
  class Matcher
    # @api private
    class LastMatch < List
      Autoloader.autoload(self)

      # @param (see List.compress)
      # @return (see List.compress)
      def self.compress(matcher_list)
        matchers = super

        invalid = matchers.delete(Invalid)
        return [Invalid] if matchers.empty? && invalid

        index = nil
        matchers.slice!(0, index) if (index = matchers.rindex(Matcher::Allow))
        matchers.slice!(0, index) if (index = matchers.rindex(Matcher::Ignore))

        matchers
          .chunk_while { |a, b| a.polarity != :mixed && a.polarity == b.polarity }
          .flat_map { |chunk| Any.compress(chunk).reverse }
          .chunk_while { |a, b| a.squashable_with?(b) }
          .map { |list| list.length == 1 ? list.first : list.first.squash(list, true) }
      end

      # @param (see Matcher#match)
      # @return (see Matcher#match)
      def match(candidate)
        @matchers.reverse_each do |matcher|
          val = matcher.match(candidate)
          return val if val
        end

        nil
      end

      private

      def calculate_weight
        super / 2.0
      end
    end
  end
end
