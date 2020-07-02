# frozen_string_literal: true

class FastIgnore
  class GitignoreIncludeRuleBuilder < GitignoreRuleBuilder
    def initialize(rule, negation, dir_only, file_path)
      super

      @current_segment_re = ::String.new
      @parent_segments = []
    end

    def unmatchable_rule!
      throw :unmatchable_rule, ::FastIgnore::UnmatchableRule
    end

    def emit(value)
      @current_segment_re << value
    end

    def emit_slash
      anchored!

      @parent_segments << @current_segment_re
      @current_segment_re = ::String.new
    end

    def emit_end_anchor
      @dir_only || emit('(/|\\z)')
    end

    def parent_dir_re # rubocop:disable Metrics/MethodLength
      segment_joins_count = @parent_segments.length
      parent_prefix = if @file_path
        segment_joins_count += @file_path.escaped_segments_length

        if @anchored
          "\\A#{@file_path.escaped_segments_joined}"
        else
          "\\A#{@file_path.escaped_segments_joined}(?:.*/)?"
        end
      else
        prefix
      end

      out = parent_prefix.dup
      unless @parent_segments.empty?
        out << '(?:'
        out << @parent_segments.join('/(?:')
        out << '/'
      end
      out << (')?' * segment_joins_count)
      out
    end

    def build_parent_dir_rule
      # Regexp::IGNORECASE = 1
      ::FastIgnore::Rule.new(::Regexp.new(parent_dir_re, 1), true, anchored_or_file_path, true)
    end

    def build_child_file_rule
      # Regexp::IGNORECASE = 1
      ::FastIgnore::Rule.new(::Regexp.new(@re + '/.', 1), @negation, anchored_or_file_path, false)
    end

    def build_rule
      @re << @parent_segments.join('/')
      @re << '/' unless @parent_segments.empty?
      @re << @current_segment_re

      rules = [super, build_parent_dir_rule]
      (rules << build_child_file_rule) if @dir_only
      rules
    end
  end
end
