# frozen_string_literal: true

class FastIgnore
  class GitignoreIncludeRuleBuilder < GitignoreRuleBuilder
    # :nocov:
    using ::FastIgnore::Backports::DeletePrefixSuffix if defined?(::FastIgnore::Backports::DeletePrefixSuffix)
    # :nocov:

    def initialize(rule, file_path, expand_path_from = nil)
      super(rule, file_path)

      @current_segment_re = ::String.new
      @parent_segments = []
      @negation = true
      @expand_path_from = expand_path_from
    end

    def expand_rule_path
      anchored! unless @s.match?(/\*/)
      return unless @s.match?(%r{(?:[~/]|\.{1,2}/|.*/\.\./)})

      dir_only! if @s.match?(%r{.*/\s*\z})
      @s.string.replace(::File.expand_path(@s.rest))
      @s.string.delete_prefix!(@expand_path_from)
      @s.pos = 0
    end

    def negated!
      @negation = false
    end

    def unmatchable_rule!
      throw :abort_build, ::FastIgnore::UnmatchableRule
    end

    def emit(value)
      @current_segment_re << value
    end

    def nothing_emitted?
      @current_segment_re.empty? && @parent_segments.empty?
    end

    def emit_dir
      anchored!

      @parent_segments << @current_segment_re
      @current_segment_re = ::String.new
    end

    def emit_end_anchor
      @dir_only || emit('(/|\\z)')
      break!
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

    def process_rule
      expand_rule_path if @expand_path_from
      super
    end
  end
end
