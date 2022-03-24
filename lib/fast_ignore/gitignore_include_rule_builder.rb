# frozen_string_literal: true

class FastIgnore
  class GitignoreIncludeRuleBuilder < GitignoreRuleBuilder
    def initialize(rule, file_path, expand_path_from = nil)
      super(rule, file_path)

      @parent_segments = []
      @negation = true
      @expand_path_from = expand_path_from
    end

    def expand_rule_path
      anchored! unless @s.match?(/\*/) # rubocop:disable Performance/StringInclude # it's StringScanner#match?
      return unless @s.match?(%r{(?:[~/]|\.{1,2}/|.*/\.\./)})

      dir_only! if @s.match?(%r{.*/\s*\z})

      @s.string.replace(PathExpander.expand_path(@s.rest, @expand_path_from))
      @s.string.delete_prefix!(@expand_path_from)
      @s.pos = 0
    end

    def negated!
      @negation = false
    end

    def unmatchable_rule!
      throw :abort_build, ::FastIgnore::UnmatchableRule
    end

    def nothing_emitted?
      @re.empty? && @parent_segments.empty?
    end

    def emit_dir
      anchored!

      @parent_segments << @re
      @re = ::FastIgnore::GitignoreRuleRegexpBuilder.new
    end

    def emit_end
      @dir_only || @re.append_end_dir_or_anchor
      break!
    end

    def parent_dir_re # rubocop:disable Metrics/MethodLength
      segment_joins_count = @parent_segments.length
      parent_prefix = if @file_path
        segment_joins_count += @file_path.escaped_segments_length

        if @anchored
          +"\\A#{@file_path.escaped_segments_joined}"
        else
          +"\\A#{@file_path.escaped_segments_joined}(?:.*/)?"
        end
      else
        prefix
      end

      out = parent_prefix
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
      ::FastIgnore::Rule.new(@re.append_dir.to_regexp, @negation, anchored_or_file_path, false)
    end

    def build_rule
      joined_re = ::FastIgnore::GitignoreRuleRegexpBuilder.new
      joined_re.append(@parent_segments.join('/'))
      joined_re.append_dir unless @parent_segments.empty?
      joined_re.append(@re)
      @re = joined_re

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
