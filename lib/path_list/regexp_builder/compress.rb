# frozen_string_literal: true

class PathList
  class RegexpBuilder
    module Compress # rubocop:disable Metrics/ModuleLength
      class << self
        # TODO: have safety around removing dup here
        def compress(parts)
          compress!(parts.dup)
        end

        private

        def prune!(*path, tail, parts)
          parts.dig(*path).delete(tail)
          if parts.dig(*path).empty?
            if path.length > 1
              prune!(*path, parts)
            else
              parts.delete(*path)
            end
          end
        end

        def compress_replace_tail!(*a, b, parts, new_tail)
          return unless parts.dig(*a)&.key?(b)

          prune!(*a, b, parts)
          Merge.merge_2!([parts, new_tail])
        end

        def compress_tail!(a, parts)
          return unless parts.key?(a)

          if parts[a].nil?
            parts.delete(a)
            true
          elsif parts[a].key?(nil)
            prune!(a, nil, parts)
            true
          end
        end

        def reject!(val, parts)
          return unless parts[val]

          Merge.merge_2!(parts, parts.delete(val) || { nil => nil })
        end

        def compress_2_keep_first!(a, b, parts)
          return unless parts[a]&.key?(b)

          Merge.merge_2!(parts[a], parts[a].delete(b) || { nil => nil })
        end

        def compress_run!(a, parts)
          compress_2_keep_first!(a, a, parts)
        end

        def compress_2_keep_last!(a, b, parts)
          compress_replace_1!(a, b, parts, b)
        end

        def compress_replace_1!(*a, b, parts, replace)
          return unless parts.dig(*a)&.key?(b)

          tail = { replace => parts.dig(*a, b) }
          prune!(*a, b, parts)
          Merge.merge_2!(parts, tail)
        end

        def compress_replace_0!(*a, b, parts)
          return unless parts.dig(*a)&.key?(b)
          tail = parts.dig(*a, b)
          prune!(*a, b, parts)
          return true if !tail && parts.empty?
          Merge.merge_2!(parts, tail || { nil => nil })
        end

        def compress_start!(parts)
          change = false
          compress_replace_0!(:start_anchor, :dir, :any_dir, :any_non_dir, parts) && change = true
          compress_replace_1!(:start_anchor, :dir, :any_dir, parts, :dir) && change = true
          compress_replace_tail!(:dir, :many_dir, :end_anchor, parts, { any_dir: :end_anchor }) && change = true
          compress_tail!(:start_anchor, parts) && change = true
          compress_tail!(:end_anchor, parts) && change = true
          change
        end

        def compress_mid_once!(parts)
          change = false
          reject!('', parts) && change = true
          reject!(nil, parts) && change = true
          compress_2_keep_first!(:many_non_dir, :any_non_dir, parts) && change = true
          compress_run!(:dir, parts) && change = true
          compress_run!(:any_dir, parts) && change = true
          compress_run!(:any_non_dir, parts) && change = true
          compress_2_keep_last!(:any_non_dir, :many_non_dir, parts) && change = true
          compress_replace_1!(:any_non_dir, :one_non_dir, parts, :many_non_dir) && change = true
          compress_replace_1!(:any_non_dir, :any_dir, parts, :any) && change = true
          compress_replace_1!(:one_non_dir, :any_non_dir, parts, :many_non_dir) && change = true
          compress_replace_1!(:any_dir, :any_non_dir, parts, :any) && change = true

          compress_replace_0!(:any_dir, :end_anchor, parts) && change = true
          compress_replace_0!(:any, :end_anchor, parts) && change = true
          compress_replace_0!(:any_dir, :any_non_dir, :end_anchor, parts) && change = true

          change
        end

        def compress_mid!(parts)
          change = false

          compress_mid_once!(parts) && change = true
          parts.each { |k, v| compress_mid!(v) && change = true if v }
          change
        end

        def compress!(parts)
          change = false

          compress_start!(parts) && change = true
          compress_mid!(parts) && change = true
          compress!(parts) if change

          parts
        end
      end
    end
  end
end
