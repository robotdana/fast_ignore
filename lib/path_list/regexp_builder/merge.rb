# frozen_string_literal: true

class PathList
  class RegexpBuilder
    module Merge
      class << self
        def merge(parts_lists) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          merged = []

          return merged if parts_lists.empty?

          start_with_fork, start_with_value = parts_lists
            .partition { |parts_list| parts_list.first.is_a?(Array) }

          if start_with_value.empty?
            merged = merge(start_with_fork.flatten(1)) unless start_with_fork.empty?
          else
            grouped_by_first = start_with_value.group_by(&:first)

            if grouped_by_first.length == 1
              if grouped_by_first.first.first.nil?
                merged
              else
                merged = Array(grouped_by_first.first.first)
                # rubocop:disable Metrics/BlockNesting
                merged += merge(start_with_value.map { |parts_list| parts_list.drop(1) })
                merged = merge([merged] + start_with_fork.flatten(1)) unless start_with_fork.empty?
                # rubocop:enable Metrics/BlockNesting
              end
            else
              new_fork = []
              merged = [new_fork]

              grouped_by_first.each do |first_item, sub_parts_lists|
                if first_item.nil?
                  new_fork << []
                else
                  tail = Array(first_item)
                  tail += merge(sub_parts_lists.map { |parts_list| parts_list.drop(1) })
                  new_fork << tail
                end
              end

              merged = merge(new_fork.flatten(1) + start_with_fork.flatten(1)) unless start_with_fork.empty?
            end
          end

          merged
        end
      end
    end
  end
end
