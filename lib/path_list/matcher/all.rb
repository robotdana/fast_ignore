# frozen_string_literal: true

class PathList
  class Matcher
    class All < List
      Autoloader.autoload(self)

      def self.compress(matchers)
        matchers = super(matchers) - [Matcher::Allow]
        return [Matcher::Allow] if matchers.empty?
        return [Matcher::Ignore] if matchers.include?(Matcher::Ignore)

        matchers.uniq!
        matchers.sort_by!(&:weight)
        matchers.freeze
      end

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
