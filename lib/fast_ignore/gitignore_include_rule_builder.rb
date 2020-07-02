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

    def append_segment_star_star_slash
      @segments += 1
      @parent_re << '(?:'
      @parent_re << @segment_re
    end

    def append_star_star_slash
      @parent_re << '.*'

      @re << @segment_re
      @re << '(?:.*/)?'
      @segment_re.clear
      @anchored = true
    end

    def process_slash_star_star_slash
      return unless @s.skip(%r{/\*{2,}/})

      append_star_star_slash
    end

    def process_slash_star_star_slash_star_end
      return unless @s.skip(%r{/\*{2,}/\*\z})

      append_star_star_slash
      append('[^/]+')
    end

    def process_star_star_slash
      return unless @s.skip(%r{\*{2,}/})

      append_segment_star_star_slash
      append_star_star_slash
    end

    def process_star_star_slash_star_end
      return unless @s.skip(%r{\*{2,}/\*\z})

      append_segment_star_star_slash
      append_star_star_slash
      append('[^/]+')
    end

    def process_slash(append)
      @segments += 1
      @parent_re << '(?:'
      @parent_re << @segment_re
      @parent_re << append

      super
    end

    def process_end
      @segment_re << '(/|\\z)'
    end

    def end_processed?
      @dir_only || super
    end

    def prepare_parent_re # rubocop:disable Metrics/MethodLength
      parent_prefix = prefix
      if @file_path
        @segments += @file_path.escaped_segments_length

        parent_prefix = if @anchored
          "\\A#{@file_path.escaped_segments_joined}"
        else
          "\\A#{@file_path.escaped_segments_joined}(?:.*/)?"
        end
      end
      @parent_re.prepend(parent_prefix)
      @parent_re << (')?' * @segments)
    end

    def build_parent_dir_rule
      prepare_parent_re

      # Regexp::IGNORECASE = 1
      ::FastIgnore::Rule.new(::Regexp.new(@parent_re, 1), true, anchored_or_file_path, true)
    end

    def build_child_file_rule
      # Regexp::IGNORECASE = 1
      ::FastIgnore::Rule.new(::Regexp.new(@re << '/.', 1), @negation, anchored_or_file_path, false)
    end

    def build_rule
      rules = [super, build_parent_dir_rule]
      (rules << build_child_file_rule) if @dir_only
      rules
    end
  end
end
