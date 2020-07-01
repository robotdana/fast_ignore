# frozen_string_literal: true

class FastIgnore
  class GitignoreIncludeRuleBuilder < GitignoreRuleBuilder
    def initialize(rule, negation, dir_only, file_path)
      super

      @segments = 0
      @parent_re = ::String.new
    end

    def unmatchable_rule!
      throw :unmatchable_rule, ::FastIgnore::UnmatchableRule
    end

    def process_star_star_slash # rubocop:disable Metrics/MethodLength
      return unless @s.skip(%r{\*{2,}/})

      unless @segment_re.empty?
        @segments += 1
        @parent_re << '(?:'
        @parent_re << @segment_re
      end
      @parent_re << '.*'

      @re << @segment_re
      @re << '(?:.*/)?'
      @segment_re.clear
      @anchored = true
    end

    def process_slash(append)
      @segments += 1
      @parent_re << '(?:'
      @parent_re << @segment_re
      @parent_re << append

      super
    end

    def build_rules # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      parent_prefix = prefix
      if @file_path
        allow_escaped_file_path = ::Regexp.escape(@file_path).gsub(%r{(?<!\\)(?:\\\\)*/}) do |e|
          @segments += 1
          "#{e[0..-2]}(?:/"
        end

        parent_prefix = if @anchored
          "\\A#{allow_escaped_file_path}"
        else
          "\\A#{allow_escaped_file_path}(?:.*/)?"
        end
      end
      @parent_re.prepend(parent_prefix)
      @parent_re << (')?' * @segments)
      (@re << '(/|\\z)') unless @dir_only || @trailing_two_stars
      rules = [
        # Regexp::IGNORECASE = 1
        ::FastIgnore::Rule.new(::Regexp.new(@re, 1), @negation, anchored_or_file_path, @dir_only),
        ::FastIgnore::Rule.new(::Regexp.new(@parent_re, 1), true, anchored_or_file_path, true)
      ]
      if @dir_only
        (rules << ::FastIgnore::Rule.new(::Regexp.new((@re << '/'), 1), @negation, anchored_or_file_path, false))
      end
      rules
    end
  end
end
