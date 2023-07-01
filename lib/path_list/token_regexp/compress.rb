# frozen_string_literal: true

class PathList
  class TokenRegexp
    module Compress
      class << self
        def compress(parts)
          compress!(parts.dup)
        end

        def compress!(parts)
          loop do
            raise if parts[0].equal?(:start_anchor) && parts[1].equal?(:start_anchor)
            next if compress_any!(parts)
            next if compress_any_dir!(parts)
            next if compress_any_non_dir!(parts)
            next if compress_start!(parts)
            next if compress_end!(parts)

            break
          end
        end

        private

        def compress_start!(parts) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          change = false
          if (parts_0 = parts[0]).equal?(:start_anchor) && parts[1].equal?(:dir)
            if (parts_2 = parts[2]).equal?(:any_dir)
              if parts[3].equal?(:any_non_dir)
                parts[0, 4] = []
              else
                parts[0, 3] = [:dir]
              end
              change = true
            elsif parts_2.equal?(:any)
              parts[0, 3] = []
              change = true
            elsif parts.length == 2
              parts.clear
              change = true
            end
          elsif parts.length == 1 && (parts_0.equal?(:end_anchor) ||
              parts_0.equal?(:dir) ||
              parts_0.equal?(:start_anchor))
            parts.clear
            change = true
          end

          change
        end

        def compress_end!(parts)
          change = false

          if parts[-1].equal?(:end_anchor) && ((parts_end_2 = parts[-2]).equal?(:any_dir) || parts_end_2.equal?(:any))
            parts[-2, 2] = []
            change = true
          end

          change
        end

        # compress_run!(:any, parts) && change = true
        # compress_run!(:any, parts) && change = true
        # compress_2_keep_first!(:any, :any_dir, parts) && change = true
        # compress_2_keep_first!(:any, :any_non_dir, parts) && change = true
        def compress_any!(parts) # rubocop:disable Metrics/MethodLength
          change = false
          from_index = nil

          while (part_index = index(parts, from_index, :any))
            if (next_part = parts[part_index + 1]).equal?(:any) ||
                next_part.equal?(:any_dir) ||
                next_part.equal?(:any_non_dir)
              change = true
              parts[part_index + 1, 1] = []
            end

            from_index = part_index + 1
          end

          change
        end

        # compress_run!(:any_dir, parts) && change = true
        # compress_replace_1!(:any_dir, :any_non_dir, parts, :any) && change = true
        # compress_replace_1!(:any_dir, :any, parts, :any) && change = true
        def compress_any_dir!(parts) # rubocop:disable Metrics/MethodLength
          change = false
          from_index = nil

          while (part_index = index(parts, from_index, :any_dir))
            if (next_part = parts[part_index + 1]).equal?(:any_dir)
              change = true
              parts[part_index + 1, 1] = []
            elsif next_part.equal?(:any_non_dir) || next_part.equal?(:any)
              change = true
              parts[part_index, 2] = [:any]
            end

            from_index = part_index + 1
          end

          change
        end

        # compress_run!(:any_non_dir, parts) && change = true
        # compress_replace_1!(:any_non_dir, :any_dir, parts, :any_dir) && change = true
        # compress_replace_1!(:any_non_dir, :any, parts, :any) && change = true
        def compress_any_non_dir!(parts) # rubocop:disable Metrics/MethodLength
          change = false
          from_index = nil

          while (part_index = index(parts, from_index, :any_non_dir))
            if (next_part = parts[part_index + 1]).equal?(:any_non_dir)
              change = true
              parts[part_index + 1, 1] = []
            elsif next_part.equal?(:any_dir) || next_part.equal?(:any)
              change = true
              parts[part_index, 1] = []
            end

            from_index = part_index + 1
          end

          change
        end

        def index(parts, from_index, part)
          if from_index
            parts[from_index..].index(part)&.+ from_index
          else
            parts.index(part)
          end
        end
      end
    end
  end
end
