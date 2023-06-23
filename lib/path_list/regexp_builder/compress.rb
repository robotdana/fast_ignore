# frozen_string_literal: true

class PathList
  class RegexpBuilder
    module Compress # rubocop:disable Metrics/ModuleLength
      START_COMPRESSION_RULES = {
        [:start_anchor, :any_non_dir, :end_anchor] => [:start_anchor, :one_non_dir], # avoid compressing this to nothing
        [:start_anchor, :any_dir] => [:dir_or_start_anchor],
        [:start_anchor, :dir, :any_dir, :any_non_dir] => [],
        [:start_anchor, :dir, :any_dir] => [:dir],
        [:start_anchor, :any] => [],
        [:dir_or_start_anchor, :any] => [],
        [:dir_or_start_anchor, :any_non_dir] => [],
        [:dir_or_start_anchor, :many_non_dir] => [:one_non_dir],
        [:dir, :many_non_dir, :end_anchor] => [:one_non_dir, :end_anchor],
        [:end_anchor] => []
      }.freeze
      private_constant :START_COMPRESSION_RULES

      END_COMPRESSION_RULES = {
        [:any_dir, :end_anchor] => [],
        [:any, :end_anchor] => [],
        [:any_dir, :any_non_dir, :end_anchor] => [],
        [:start_anchor] => [],
        [:dir_or_start_anchor] => []
      }.freeze

      private_constant :END_COMPRESSION_RULES

      class << self
        def compress(parts)
          compress!(parts.dup)
        end

        private

        def compress_start!(parts)
          START_COMPRESSION_RULES.each do |rule, replacement|
            parts[0, rule.length] = replacement if rule == parts.take(rule.length)
          end
        end

        def compress_end!(parts)
          END_COMPRESSION_RULES.each do |rule, replacement|
            parts[-1 * rule.length, rule.length] = replacement if rule == parts.slice(-1 * rule.length, rule.length)
          end
        end

        def index_offset(parts, query, offset)
          return parts.index(query) if offset.zero?

          # TODO: use index
          parts.drop(offset).index(query)&.+ offset
        end

        def compress_any_non_dir!(parts)
          index = 0

          while (index = index_offset(parts, :any_non_dir, index))
            case parts[index + 1]
            when :any_non_dir, :many_non_dir then parts.delete_at(index)
            when :one_non_dir then parts[index, 2] = [:many_non_dir]
            when :any_dir then parts[index, 2] = [:any]
            else index += 1
            end
          end
        end

        def compress_many_non_dir!(parts)
          index = 0

          while (index = index_offset(parts, :many_non_dir, index))
            case parts[index + 1]
            when :any_non_dir then parts.delete_at(index)
            else index += 1
            end
          end
        end

        def compress_one_non_dir!(parts)
          index = 0

          while (index = index_offset(parts, :one_non_dir, index))
            case parts[index + 1]
            when :any_non_dir then parts[index, 2] = [:many_non_dir]
            else index += 1
            end
          end
        end

        def compress_any_dir!(parts)
          index = 0

          while (index = index_offset(parts, :any_dir, index))
            case parts[index + 1]
            when :any_non_dir then parts[index, 2] = [:any]
            else index += 1
            end
          end
        end

        # would like a squeeze method
        def compress_dir!(parts)
          index = 0

          while (index = index_offset(parts, :dir, index))
            case parts[index + 1]
            when :dir then parts.delete_at(index)
            else index += 1
            end
          end
        end

        def compress_mid!(parts)
          compress_any_non_dir!(parts)
          compress_many_non_dir!(parts)
          compress_one_non_dir!(parts)
          compress_any_dir!(parts)
          parts.delete('')
          compress_dir!(parts)
        end

        def compress!(parts)
          original_length = parts.length
          parts.compact!

          compress_start!(parts)
          compress_mid!(parts)
          compress_end!(parts)

          compress!(parts) if parts.length < original_length

          parts
        end
      end
    end
  end
end
