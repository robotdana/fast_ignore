# frozen_string_literal: true

class PathList
  class Rule
    def initialize(re_builder = RegexpBuilder.new([:dir_or_start_anchor]), negated = false)
      @negated = negated
      @unanchorable = false
      @dir_only = false
      @re = re_builder
    end

    def negated!
      @negated = true
    end

    def unnegated!
      @negated = false
    end

    def negated?
      @negated
    end

    def anchored!
      @re.anchored!
    end

    def anchored?
      @re.anchored?
    end

    def never_anchored!
      @re.never_anchored!
    end

    def dir_only!
      @dir_only = true
    end

    def dir_only?
      @dir_only
    end

    def build_path_matcher
      Matchers::PathRegexp.build(@re, negated?)
    end

    def build
      if dir_only?
        Matchers::MatchIfDir.build(build_path_matcher)
      else
        build_path_matcher
      end
    end

    def build_parents(negated = true) # Metrics/AbcSize
      ancestors = @re.ancestors.each(&:compress)
      return Matchers::Blank if ancestors.empty?

      Matchers::MatchIfDir.build(
        Matchers::PathRegexp.build(RegexpBuilder.union(ancestors), negated)
      )
    end

    def empty?
      @re.empty?
    end

    def dup
      out = super

      @re = @re.dup

      out
    end

    def end_with?(part)
      @re.end_with?(part)
    end

    def compress
      @re.compress
    end

    def remove_end_anchor_for_include
      @re.remove_end_anchor_for_include
    end

    def character_class_open
      @re.character_class_open
    end

    def character_class_close
      @re.character_class_close
    end

    def character_class_append(value)
      @re.character_class_append(value)
    end

    def character_class_append_string(value)
      @re.character_class_append_string(value)
    end

    def append_string(value)
      @re.append_string(value)
    end

    def append(value)
      @re.append(value)
    end
  end
end
