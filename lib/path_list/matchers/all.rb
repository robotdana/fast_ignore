# frozen_string_literal: true

class PathList
  module Matchers
    class All < List
      def self.compress(matchers)
        matchers = super(matchers) - [Allow]
        return [Allow] if matchers.empty?

        matchers.sort_by(&:weight).uniq
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
