# frozen_string_literal: true

class FastIgnore
  module FNMatchToRegex
    # This doesn't look rubyish because i ported it from rust (the only rust i ever wrote that worked)
    class << self
      def call(pattern) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        re = '\\A'.dup

        in_character_group = false
        has_characters_in_group = false
        escape_next_character = false
        last_char_opened_character_group = false
        negated_character_group = false
        stars = 0

        pattern.each_char do |char| # rubocop:disable Metrics/BlockLength
          if escape_next_character
            re << Regexp.escape(char)
            escape_next_character = false
          elsif char == '\\' # single char, just needs to be escaped
            escape_next_character = true
          elsif in_character_group
            if char == '/'
              if negated_character_group
                has_characters_in_group = true
                re << char
              end
            elsif char == '^'
              if last_char_opened_character_group
                re << char
                negated_character_group = true
              else
                re << '\\^'
                has_characters_in_group = true
              end
              # not characters in group
            elsif char == ']'
              break unless has_characters_in_group

              re << ']'
              in_character_group = false
              has_characters_in_group = false
              negated_character_group = false
              last_char_opened_character_group = false
            elsif char == '-'
              has_characters_in_group = true
              re << char
            else
              has_characters_in_group = true
              re << Regexp.escape(char)
            end
            last_char_opened_character_group = false
          elsif char == '*'
            stars += 1
          elsif char == '/'
            re << if stars >= 2
              '(?:.*/)?'
            elsif stars.positive?
              '[^/]*/'
            else
              char
            end
            stars = 0
          else
            if stars.positive?
              re << '[^/]*'
              stars = 0
            end
            if char == '?'
              re << '[^/]'
            elsif char == '['
              re << '['
              in_character_group = true
              last_char_opened_character_group = true
            else
              re << Regexp.escape(char)
            end
          end
        end

        if in_character_group
          return /(?!)/ # impossible to match anything
        end

        if stars >= 2
          re << '.*'
        elsif stars.positive?
          re << '[^/]*'
        end
        re << '\\z'
        Regexp.new(re, Regexp::IGNORECASE)
      end
    end
  end
end
