# frozen_string_literal: true

class PathList
  class RegexpBuilder
    class CharacterClassBuilder < Builder
      class << self
        private

        def build_part(part)
          case part
          when :character_class_non_slash_open then '(?!/)['
          when :character_class_negation then '^'
          when :character_class_dash then '-'
          when :character_class_close then ']'
          when nil, String then part
          when Hash then to_s(part)
          else raise "Unknown token #{part.inspect}"
          end
        end
      end
    end
  end
end
