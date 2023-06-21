# frozen_string_literal: true

class PathList
  class RegexpBuilder
    module Compress
      START_COMPRESSION_RULES = {
        [:start_anchor, :any_non_dir, :end_anchor] => [:start_anchor, :one_non_dir], # avoid compressing this to nothing
        [:start_anchor, :any_dir] => [:dir_or_start_anchor],
        [:start_anchor, :any] => [],
        [:dir_or_start_anchor, :any] => [],
        [:dir_or_start_anchor, :any_non_dir] => [],
        [:dir_or_start_anchor, :many_non_dir] => [:one_non_dir],
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

      MID_COMPRESSION_RULES = {
        # needs to be the same length
        [:any_non_dir, :any_non_dir] => [nil, :any_non_dir],
        [:one_non_dir, :any_non_dir] => [nil, :many_non_dir],
        [:any_non_dir, :one_non_dir] => [nil, :many_non_dir],
        [:many_non_dir, :any_non_dir] => [nil, :many_non_dir],
        [:any_non_dir, :many_non_dir] => [nil, :many_non_dir],
        [:any_non_dir, :any_dir] => [nil, :any]
      }.freeze

      private_constant :MID_COMPRESSION_RULES

      class << self
        def compress(parts)
          compress!(parts.dup)
        end

        private

        def compress!(parts) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          changed = false

          START_COMPRESSION_RULES.each do |rule, replacement|
            if rule == parts.take(rule.length)
              parts[0, rule.length] = replacement
              changed = true
            end
          end

          END_COMPRESSION_RULES.each do |rule, replacement|
            if rule == parts.slice(-1 * rule.length, rule.length)
              parts[-1 * rule.length, rule.length] = replacement
              changed = true
            end
          end

          MID_COMPRESSION_RULES.each do |rule, replacement|
            parts.each_cons(rule.length).with_index do |parts_cons, index|
              if rule == parts_cons
                parts[index, rule.length] = replacement
                changed = true
              end
            end
            parts.compact!
          end

          compress!(parts) if changed

          parts
        end
      end
    end
  end
end
