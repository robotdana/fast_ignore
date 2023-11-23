# frozen_string_literal: true

require 'strscan'

class PathList
  class PatternParser
    class Gitignore
      # @api private
      class WindowsRuleScanner < RuleScanner
        # @return [Boolean]
        def slash?
          skip(%r{[\\/]})
        end

        # @return [String, nil]
        def root_end
          # / or \ or UMC path or driver letter
          matched if scan(%r{(?:[\\/]{1,2}|[a-zA-Z]:[\\/])\s*\z})
        end

        # @return [String, nil]
        def root
          # / or \ or UMC path or driver letter
          matched if scan(%r{(?:[\\/]{1,2}|[a-zA-Z]:[\\/])})
        end

        # @return [String, nil]
        def home_slash_end
          '~' if scan(%r{~[\\/]\s*\z})
        end

        # @return [String, nil]
        def home_slash_or_end
          '~' if scan(%r{~(?:[\\/]|\s*\z)})
        end

        # @return [Boolean]
        def dot_slash_or_end?
          skip(%r{\.(?:[\\/]|\s*\z)})
        end

        # @return [Boolean]
        def dot_slash_end?
          skip(%r{\.[\\/]\s*\z})
        end

        # @return [Boolean]
        def dot_dot_slash_end?
          skip(%r{\.\.[\\/]\s*\z})
        end

        # @return [Boolean]
        def dot_dot_slash_or_end?
          skip(%r{\.\.(?:[\\/]|\s*\z)})
        end

        # @return [Boolean]
        def slash_end?
          skip(%r{[\\/]\s*\z})
        end

        # @return [Boolean]
        def escape?
          skip(/`/)
        end

        # @return [Boolean]
        def star_star_slash_end?
          skip(%r{\*{2,}[\\/]\s*\z})
        end

        # @return [Boolean]
        def star_star_slash_slash?
          skip(%r{\*{2,}[\\/]{2}})
        end

        # @return [Boolean]
        def slash_slash?
          skip(%r{[\\/]{2}})
        end

        # @return [Boolean]
        def star_star_slash?
          skip(%r{\*{2,}[\\/]})
        end

        # @return [Boolean]
        def slash_star_star_end?
          skip(%r{[\\/]\*{2,}\s*\z})
        end

        # @return [String, nil]
        def character_class_literal
          matched if scan(/[^\]`][^\]`-]*(?!-)/)
        end

        # @return [String, nil]
        def character_class_range_start
          matched.delete_prefix('`') if scan(/(`.|[^`\]])(?=-(`.|[^`\]]))/)
        end

        # @return [String, nil]
        def character_class_range_end
          # we already confirmed this was going to match
          # with the lookahead in character_class_range_start
          skip(/-/)
          scan(/(`.|[^`\]])/)
          matched.delete_prefix('`')
        end

        # @return [String, nil]
        def literal
          matched if scan(%r{[^*\\/?\[`\s]+})
        end
      end
    end
  end
end
