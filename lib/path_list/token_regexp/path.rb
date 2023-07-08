# frozen_string_literal: true

class PathList
  class TokenRegexp
    # @api private
    class Path < TokenRegexp
      # @param path [String]
      # @param tail [Array<Symbol, String, EscapedString>]
      # @return [TokenRegexp::Path]
      def self.new_from_path(path, tail = [:end_anchor])
        new(
          [:start_anchor] +
          path.delete_prefix('/').split('/').flat_map do |part|
            [:dir, part]
          end +
          tail
        )
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
        prev_rule = [:start_anchor]
        rules = [self.class.new([:start_anchor, :dir, :end_anchor])]
        parts = @parts
        any_dir_index = parts.index(:any) || parts.index(:any_dir)
        parts = parts[0, any_dir_index] + [:any, :dir] if any_dir_index
        parts.slice_before(:dir).to_a[1...-1].each do |chunk|
          prev_rule.concat(chunk)
          rules << self.class.new(prev_rule + [:end_anchor])
        end
        rules[-1].compress
        rules
      end
    end
  end
end
