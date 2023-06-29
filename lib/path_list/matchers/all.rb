# frozen_string_literal: true

class PathList
  module Matchers
    class All < List
      include Autoloader

      def self.compress(matchers)
        matchers = super(matchers) - [Matchers::Allow]
        return [Matchers::Allow] if matchers.empty?
        return [Matchers::Ignore] if matchers.include?(Matchers::Ignore)

        matchers.sort_by!(&:weight)
        matchers.uniq!
        matchers.freeze
      end

      def match(candidate)
        default = :allow

        @matchers.each do |m|
          if (result = m.match(candidate)) == :ignore
            return :ignore
          elsif result.nil?
            default = nil
          end
        end

        default
      end

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
