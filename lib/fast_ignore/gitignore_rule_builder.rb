# frozen_string_literal: true

class FastIgnore
  class GitignoreRuleBuilder # rubocop:disable Metrics/ClassLength
    def initialize(rule, negation, dir_only, file_path, allow) # rubocop:disable Metrics/MethodLength
      @re = ::String.new
      @segment_re = ::String.new
      @allow = allow
      if @allow
        @segments = 0
        @parent_re = ::String.new
      end

      @s = ::StringScanner.new(rule)

      @dir_only = dir_only
      @file_path = (file_path if file_path && !file_path.empty?)
      @negation = negation
      @anchored = false
      @trailing_stars = false
    end

    def process_escaped_char
      @segment_re << ::Regexp.escape(@s.matched[1]) if @s.scan(/\\./)
    end

    def process_character_class
      return unless @s.skip(/\[/)

      @segment_re << '['
      process_character_class_body(false)
    end

    def process_negated_character_class
      return unless @s.skip(/\[\^/)

      @segment_re << '[^'
      process_character_class_body(true)
    end

    def unmatchable_rule!
      throw :unmatchable_rule, (
        @allow ? ::FastIgnore::UnmatchableRule : []
      )
    end

    def process_character_class_end
      return unless @s.skip(/\]/)

      unmatchable_rule! unless @has_characters_in_group

      @segment_re << ']'
    end

    def process_character_class_body(negated_class) # rubocop:disable Metrics/MethodLength
      @has_characters_in_group = false
      until process_character_class_end
        if @s.eos?
          unmatchable_rule!
        elsif process_escaped_char
          @has_characters_in_group = true
        elsif @s.skip(%r{/})
          next unless negated_class

          @has_characters_in_group = true
          @segment_re << '/'
        elsif @s.skip(/-/)
          @has_characters_in_group = true
          @segment_re << '-'
        else @s.scan(%r{[^/\]\-]+})
             @has_characters_in_group = true
             @segment_re << ::Regexp.escape(@s.matched)
        end
      end
    end

    def process_star_star_slash
      return unless @s.skip(%r{\*{2,}/})

      if @allow
        if @segment_re.empty?
          @parent_re << '.*'
        else
          process_slash_allow('.*')
        end
      end
      process_slash('(?:.*/)?')
    end

    def process_star_slash
      return unless @s.skip(%r{\*/})

      process_slash_allow('[^/]*/') if @allow
      process_slash('[^/]*/')
    end

    def process_no_star_slash
      return unless @s.skip(%r{/})

      process_slash_allow('/') if @allow
      process_slash('/')
    end

    def process_slash(append)
      @re << @segment_re
      @re << append
      @segment_re.clear
      @anchored = true
    end

    def process_slash_allow(append)
      @segments += 1
      @parent_re << '(?:'
      @parent_re << @segment_re
      @parent_re << append
    end

    def process_stars
      (@segment_re << '[^/]*') if @s.scan(%r{\*+(?=[^*/])})
    end

    def process_question_mark
      (@segment_re << '[^/]') if @s.skip(/\?/)
    end

    def process_text
      (@segment_re << ::Regexp.escape(@s.matched)) if @s.scan(%r{[^*/?\[\\]+})
    end

    def process_end
      return unless @s.scan(/\*+\z/)

      if @s.matched.length == 1
        @segment_re << if @segment_re.empty? # at least something. this is to allow subdir negations to work
          '[^/]+\\z'
        else
          '[^/]*\\z'
        end
      end
      @trailing_stars = true
    end

    def process_rule
      until @s.eos?
        process_escaped_char ||
          process_star_star_slash || process_star_slash || process_no_star_slash ||
          process_stars || process_question_mark ||
          process_negated_character_class || process_character_class ||
          process_text || process_end
      end
    end

    def build # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      @anchored = true if @s.skip(%r{/})

      catch :unmatchable_rule do # rubocop:disable Metrics/BlockLength
        process_rule

        @re << @segment_re

        prefix = if @file_path
          escaped_file_path = ::Regexp.escape @file_path
          if @anchored
            "\\A#{escaped_file_path}"
          else
            "\\A#{escaped_file_path}(?:.*/)?"
          end
        else
          if @anchored
            '\\A'
          else
            '(?:\\A|/)'
          end
        end

        @re.prepend(prefix)
        anchored_or_file_path = @anchored || @file_path
        if @allow
          if @file_path
            allow_escaped_file_path = escaped_file_path.gsub(%r{(?<!\\)(?:\\\\)*/}) do |e|
              @segments += 1
              "#{e[0..-2]}(?:/"
            end

            prefix = if @anchored
              "\\A#{allow_escaped_file_path}"
            else
              "\\A#{allow_escaped_file_path}(?:.*/)?"
            end
          end
          @parent_re.prepend(prefix)
          @parent_re << (')?' * @segments)
          (@re << '(/|\\z)') unless @dir_only || @trailing_stars
          rules = [
            # Regexp::IGNORECASE = 1
            ::FastIgnore::Rule.new(::Regexp.new(@re, 1), @negation, anchored_or_file_path, @dir_only),
            ::FastIgnore::Rule.new(::Regexp.new(@parent_re, 1), true, anchored_or_file_path, true)
          ]
          if @dir_only
            (rules << ::FastIgnore::Rule.new(::Regexp.new((@re << '/.*'), 1), @negation, anchored_or_file_path, false))
          end
          rules
        else
          (@re << '\\z') unless @trailing_stars

          # Regexp::IGNORECASE = 1
          ::FastIgnore::Rule.new(::Regexp.new(@re, 1), @negation, anchored_or_file_path, @dir_only)
        end
      end
    end
  end
end
