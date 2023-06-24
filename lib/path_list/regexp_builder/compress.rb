# frozen_string_literal: true

class PathList
  class RegexpBuilder
    module Compress
      class << self # rubocop:disable Metrics/ClassLength
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

        def compress_replace_tail!(*path, tail, parts, new_tail)
          return unless parts.dig(*path)&.key?(tail)

          prune!(*path, tail, parts)
          Merge.merge_2!([parts, new_tail])
        end

        def compress_tail!(part, parts)
          return unless parts.key?(part)

          if parts[part].nil?
            parts.delete(part)
            true
          elsif parts[part].key?(nil)
            prune!(part, nil, parts)
            true
          end
        end

        def compress_2_tail!(head, tail, parts)
          return unless parts[head]&.key?(tail) && (parts.dig(head,
                                                              tail).nil? || parts.dig(head, tail) == { nil => nil })

          prune!(head, tail, parts)
          true
        end

        def reject!(part, parts)
          return unless parts[part]

          Merge.merge_2!(parts, parts.delete(part) || { nil => nil })
        end

        def compress_2_keep_first!(head, tail, parts)
          return unless parts[head]&.key?(tail)

          Merge.merge_2!(parts[head], parts[head].delete(tail) || { nil => nil })
        end

        def compress_run!(part, parts)
          compress_2_keep_first!(part, part, parts)
        end

        def compress_keep_last!(*path, tail, parts)
          compress_replace_1!(*path, tail, parts, tail)
        end

        def compress_replace_1!(*path, tail, parts, replace)
          return unless parts.dig(*path)&.key?(tail)

          new_tail = { replace => parts.dig(*path, tail) }
          prune!(*path, tail, parts)
          Merge.merge_2!(parts, new_tail)
        end

        def compress_1_replace_0!(part, parts)
          return unless parts.key?(part)

          tail = parts[part]
          parts.delete(part)
          return parts.replace(nil => nil) if !tail && parts.empty?

          Merge.merge_2!(parts, tail || { nil => nil })
        end

        def compress_replace_0!(*path, tail, parts)
          return unless parts.dig(*path)&.key?(tail)

          new_tail = parts.dig(*path, tail)
          prune!(*path, tail, parts)
          return parts.replace(nil => nil) if !new_tail && parts.empty?

          Merge.merge_2!(parts, new_tail || { nil => nil })
        end

        def remove_second_option(head, tail, parts)
          return unless parts.key?(head) && parts.key?(tail)

          parts.delete(tail)
          true
        end

        def compress_start!(parts) # rubocop:disable Metrics/MethodLength
          change = false
          compress_replace_0!(:start_anchor, :dir, :any_dir, :any_non_dir, parts) && change = true
          compress_replace_1!(:start_anchor, :dir, :any_dir, parts, :dir) && change = true
          compress_replace_0!(:start_anchor, :dir, :any, parts) && change = true
          compress_1_replace_0!(:any_non_dir, parts)
          compress_replace_tail!(:dir, :many_dir, :end_anchor, parts, { any_dir: :end_anchor }) && change = true
          compress_tail!(:start_anchor, parts) && change = true
          compress_tail!(:end_anchor, parts) && change = true
          compress_tail!(:dir, parts) && change = true
          compress_2_tail!(:start_anchor, :dir, parts) && change = true
          change
        end

        def compress_mid_once!(parts) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          change = false
          reject!('', parts) && change = true
          reject!(nil, parts) && change = true
          compress_2_keep_first!(:many_non_dir, :any_non_dir, parts) && change = true
          compress_run!(:dir, parts) && change = true
          compress_run!(:any_dir, parts) && change = true
          compress_run!(:any_non_dir, parts) && change = true
          compress_keep_last!(:any_non_dir, :many_non_dir, parts) && change = true
          compress_keep_last!(:any_dir, :any, parts) && change = true
          compress_2_keep_first!(:any, :any_non_dir, parts) && change = true
          compress_replace_1!(:any_non_dir, :one_non_dir, parts, :many_non_dir) && change = true
          compress_replace_1!(:any_non_dir, :any_dir, parts, :any) && change = true
          compress_replace_1!(:one_non_dir, :any_non_dir, parts, :many_non_dir) && change = true
          # compress_replace_0!(:any_dir, :any_non_dir, :end_anchor, parts) && change = true
          compress_replace_1!(:any_dir, :any_non_dir, parts, :any) && change = true

          remove_second_option(:any_dir, :end_anchor, parts) && change = true
          remove_second_option(:any, :end_anchor, parts) && change = true

          compress_replace_0!(:any_dir, :end_anchor, parts) && change = true
          compress_replace_0!(:any, :end_anchor, parts) && change = true

          change
        end

        def compress_mid!(parts)
          change = false

          compress_mid_once!(parts) && change = true
          parts.each { |_k, v| compress_mid!(v) && change = true if v }
          change
        end

        def compress!(parts)
          change = false

          compress_mid!(parts) && change = true
          compress_start!(parts) && change = true
          compress!(parts) if change

          parts
        end
      end
    end
  end
end
