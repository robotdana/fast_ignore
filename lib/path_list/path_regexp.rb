# frozen_string_literal: true

class PathList
  class PathRegexp < TokenRegexp
    def self.new_from_path(path, tail = [:end_anchor])
      new(
        [:start_anchor] +
        path.delete_prefix('/').split('/').flat_map do |part|
          [:dir, part]
        end +
        tail
      )
    end

    def exact_path?
      @parts[0] == :start_anchor && @parts[-1] == :end_anchor &&
        @parts[1...-1].all? { |part| part.equal?(:dir) || part.is_a?(String) }
    end

    def compress
      Compress.compress!(@parts)

      @parts.freeze

      self
    end

    def ancestors # rubocop:disable Metrics/AbcSize
      prev_rule = [:start_anchor]
      rules = [self.class.new([:start_anchor, :dir, :end_anchor])]
      parts = @parts
      any_dir_index = parts.index(:any) || parts.index(:any_dir)
      parts = parts[0, any_dir_index] + [:any, :dir] if any_dir_index
      parts.slice_before(:dir).to_a[1...-1].each do |chunk|
        prev_rule.concat(chunk)
        rules << self.class.new(prev_rule + [:end_anchor]).compress
      end
      rules
    end
  end
end
