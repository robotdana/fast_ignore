# frozen_string_literal: true

class FastIgnore
  module Matchers
    AllowAnyParent = Base.new

    class << AllowAnyParent
      def dir_only?
        true
      end

      def implicit?
        true
      end

      def inspect
        '#<FastIgnore::Matchers::AllowAnyParent>'
      end

      def match(candidate)
        :allow if candidate.parent?
      end
    end

    AllowAnyParent.freeze
  end
end
