# frozen_string_literal: true

class FastIgnore
  module Matchers
    AllowAny = Base.new

    class << AllowAny
      def implicit?
        true
      end

      def inspect
        '#<FastIgnore::Matchers::AllowAny>'
      end

      def match(_)
        :allow
      end

      freeze
    end

    AllowAny.freeze
  end
end
