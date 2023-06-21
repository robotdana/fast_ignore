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
          else raise "Unknown token #{token}"
          end
        end
      end
    end
  end
end
