# frozen_string_literal: true

class PathList
  module Matchers
    class All < List
      include Autoloader

      def self.compress(matchers)
        matchers = super(matchers) - [Matchers::Allow]
        return [Matchers::Allow] if matchers.empty?

        matchers.sort_by!(&:weight)
        matchers.uniq!
        matchers.freeze
      end

      def match(candidate)
        default = :allow

        @matchers.each do |m|
          case m.match(candidate)
          when :ignore then return :ignore
          when nil then default = nil
          end
        end

        default
      end

      private

      def calculate_weight
        super + 1
      end
    end
  end
end
