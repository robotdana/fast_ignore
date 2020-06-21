# frozen_string_literal: true

class FastIgnore
  module GitignoreRuleBuilder # rubocop:disable Metrics/ModuleLength
    class << self
      def build(rule, negation, dir_only, file_path, allow) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        re = ''.dup
        segment_re = ''.dup

        unanchored = true
        first_char = true
        in_character_group = false
        has_characters_in_group = false
        prev_char_escapes = false
        prev_char_opened_character_group = false
        negated_character_group = false
        stars = 0
        segment_re_empty = true

        if allow
          segments = 0
          parent_re = ''.dup
        end

        rule.each_char do |char| # rubocop:disable Metrics/BlockLength
          if prev_char_escapes
            segment_re << Regexp.escape(char)
            segment_re_empty = false
            prev_char_escapes = false
          elsif char == '\\' # single char, just needs to be escaped
            prev_char_escapes = true
          elsif in_character_group
            case char
            when '/'
              if negated_character_group
                has_characters_in_group = true
                segment_re << char
              end
            when '^'
              if prev_char_opened_character_group
                segment_re << char
                negated_character_group = true
              else
                segment_re << '\\^'
                has_characters_in_group = true
              end
              # not characters in group
            when ']'
              break unless has_characters_in_group

              segment_re << ']'
              in_character_group = false
              has_characters_in_group = false
              negated_character_group = false
              prev_char_opened_character_group = false
            when '-'
              has_characters_in_group = true
              segment_re << char
            else
              has_characters_in_group = true
              segment_re << Regexp.escape(char)
            end
            prev_char_opened_character_group = false
          elsif char == '*'
            stars += 1
          elsif char == '/'
            unless first_char
              if allow
                if stars >= 2 && segment_re_empty # rubocop:disable Metrics/BlockNesting
                  parent_re << '.*'
                else
                  segments += 1
                  parent_re << '(?:'

                  parent_re << segment_re
                  if stars >= 2 # rubocop:disable Metrics/BlockNesting
                    parent_re << '.*'
                  elsif stars == 1 # rubocop:disable Metrics/BlockNesting
                    parent_re << '[^/]*/'
                  end
                end
              end

              segment_re << if stars >= 2
                '(?:.*/)?'
              elsif stars == 1
                '[^/]*/'
              else
                char
              end
              re << segment_re
              segment_re.clear
              segment_re_empty = true
              stars = 0
            end
            unanchored = false
          else
            if stars.positive?
              segment_re << '[^/]*'
              segment_re_empty = false
              stars = 0
            end
            case char
            when '?'
              segment_re << '[^/]'
              segment_re_empty = false
            when '['
              segment_re << '['
              segment_re_empty = false
              in_character_group = true
              prev_char_opened_character_group = true
            else
              segment_re << Regexp.escape(char)
              segment_re_empty = false
            end
          end
          first_char = false
        end

        re << segment_re

        return ::FastIgnore::Rule.new(/(?!)/, negation, unanchored, dir_only) if in_character_group

        prefix = if file_path
          escaped_file_path = Regexp.escape file_path
          if unanchored
            "\\A#{escaped_file_path}(?:.*/)?"
          else
            "\\A#{escaped_file_path}"
          end
        else
          if unanchored
            '\\A(?:.*/)?'
            # Theoretically these could be faster. I'm disappointed they're not
            # "(?:\\A|/)"
            # "(?<![^/])"
          else
            '\\A'
          end
        end

        re.prepend(prefix)

        if allow
          if file_path
            allow_escaped_file_path = escaped_file_path.gsub(%r{(?<!\\)(?:\\\\)*/}) do |e|
              segments += 1
              "#{e[0..-2]}(?:/"
            end

            prefix = if unanchored
              "\\A#{allow_escaped_file_path}(?:.*/)?"
            else
              "\\A#{allow_escaped_file_path}"
            end
          end
          parent_re.prepend(prefix)
          parent_re << (')?' * segments)
          if dir_only
            [
              # Regexp::IGNORECASE = 1
              ::FastIgnore::Rule.new(Regexp.new(re, 1), negation, unanchored, dir_only),
              ::FastIgnore::Rule.new(Regexp.new((re << '/.*'), 1), negation, unanchored, false),
              ::FastIgnore::Rule.new(Regexp.new(parent_re, 1), true, unanchored, true)
            ]
          else
            re << '(/|\\z)' unless stars.positive?
            [
              # Regexp::IGNORECASE = 1
              ::FastIgnore::Rule.new(Regexp.new(re, 1), negation, unanchored, dir_only),
              ::FastIgnore::Rule.new(Regexp.new(parent_re, 1), true, unanchored, true)
            ]
          end
        else
          if stars == 1
            re << '[^/]*\\z'
          elsif stars.zero?
            re << '\\z'
          end

          # Regexp::IGNORECASE = 1
          ::FastIgnore::Rule.new(Regexp.new(re, 1), negation, unanchored, dir_only)
        end
      end
    end
  end
end
