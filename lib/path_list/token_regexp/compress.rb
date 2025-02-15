# frozen_string_literal: true

class PathList
  class TokenRegexp
    # @api private
    module Compress
      class << self
        # @param parts [Array<Symbol, String, EscapedString>]
        # @return [Array<Symbol, String, EscapedString>]
        def compress!(parts)
          loop do
            next if compress_any!(parts)
            next if compress_any_dir!(parts)
            next if compress_any_non_dir!(parts)
            next if compress_start!(parts)
            next if compress_end!(parts)

            break
          end
        end

        private

        def compress_start!(parts)
          change = false
          if :start_anchor == (parts_0 = parts[0]) && :dir == parts[1]
            if :any_dir == (parts_2 = parts[2])
              parts[0, 3] = [:dir]
              change = true
            elsif :any == parts_2
              parts[0, 3] = []
              change = true
            end
          elsif parts.length == 1 && (:end_anchor == parts_0 || :dir == parts_0 || :start_anchor == parts_0)
            parts.clear
            change = true
          end

          change
        end

        def compress_end!(parts)
          change = false

          if :end_anchor == parts[-1] && (:any_dir == (parts_end_2 = parts[-2]) || :any == parts_end_2)
            parts[-2, 2] = []
            change = true
          end

          change
        end

        def compress_any!(parts)
          change = false
          from_index = nil

          while (part_index = index(parts, from_index, :any))
            from_index = part_index + 1

            if :any == (next_part = parts[from_index]) || :any_dir == next_part || :any_non_dir == next_part
              change = true
              parts[from_index, 1] = []
            end

          end

          change
        end

        def compress_any_dir!(parts)
          change = false
          from_index = nil

          while (part_index = index(parts, from_index, :any_dir))
            from_index = part_index + 1

            if :any_dir == (next_part = parts[from_index])
              change = true
              parts[from_index, 1] = []
            elsif :any_non_dir == next_part || :any == next_part
              change = true
              parts[part_index, 2] = [:any]
            end
          end

          change
        end

        def compress_any_non_dir!(parts)
          change = false
          from_index = nil

          while (part_index = index(parts, from_index, :any_non_dir))
            from_index = part_index + 1

            if :any_non_dir == parts[from_index]
              change = true
              parts[from_index, 1] = []
            end
          end

          change
        end

        def index(parts, from_index, part)
          if from_index
            parts[from_index..-1].index(part)&.+ from_index
          else
            parts.index(part)
          end
        end
      end
    end
  end
end
