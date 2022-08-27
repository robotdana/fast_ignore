# frozen_string_literal: true

class FastIgnore
  module Matchers
    class All < List
      def initialize(matchers)
        matchers = matchers.flat_map { |m| m.is_a?(All) ? m.matchers : m }
        matchers.reject!(&:removable?)
        matchers.sort_by!(&:weight)
        @matchers = matchers.freeze
      end

      def match(candidate)
        if @matchers.all? { |m| m.match(candidate) == :allow }
          :allow
        else
          :ignore
        end
      end
    end
  end
end
