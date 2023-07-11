# frozen_string_literal: true

class PathList
  class TokenRegexp
    # @api private
    class Path < TokenRegexp
      # @param path [String]
      # @param tail [Array<Symbol, String, EscapedString>]
      # @return [TokenRegexp::Path]
      def self.new_from_path(path, tail = [:end_anchor])
        parts = [:start_anchor]
        split = path.split('/')
        (parts << (CanonicalPath.case_insensitive? ? split[0].downcase : split[0])) if split[0] && !split[0].empty?
        (parts << :dir) if split.length == 1 || (split.empty? && path == '/')
        split.drop(1).each do |part|
          parts << :dir
          parts << (CanonicalPath.case_insensitive? ? part.downcase : part)
        end
        parts.concat(tail)

        new(parts)
      end

      # @return [Boolean]
      def exact_path?
        :start_anchor == @parts[0] && :end_anchor == @parts[-1] &&
          @parts[1...-1].all? { |part| :dir == part || part.instance_of?(String) }
      end

      # @return [self]
      def compress
        Compress.compress!(@parts)

        @parts.freeze

        self
      end

      # @return [Array<TokenRegexp::Path>]
      def ancestors
        prev_rule = []
        rules = []
        parts = @parts
        any_dir_index = parts.index(:any) || parts.index(:any_dir)
        parts = parts[0, any_dir_index] + [:any, :dir] if any_dir_index
        parts = parts.slice_before(:dir)
        prev_rule.concat(parts.first)
        rules << self.class.new(prev_rule + [:dir, :end_anchor])
        parts.to_a[1...-1].each do |chunk|
          prev_rule.concat(chunk)
          rules << self.class.new(prev_rule + [:end_anchor])
        end
        rules[-1].compress
        rules
      end

      # @param (see TokenRegexp#append_string)
      # @return (see TokenRegexp#append_string)
      def append_string(value)
        return unless value

        append_part(
          if CanonicalPath.case_insensitive?
            value.downcase
          else
            value
          end
        )
      end
    end
  end
end
