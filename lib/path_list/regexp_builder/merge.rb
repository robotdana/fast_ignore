# frozen_string_literal: true

class PathList
  class RegexpBuilder
    module Merge
      class << self
        def merge(parts_lists) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          return parts_lists if parts_lists.empty?

          parts_lists = flatten_forks(parts_lists)

          grouped_by_first = parts_lists.group_by(&:first)

          if grouped_by_first.length == 1
            if grouped_by_first.first.first.nil?
              []
            else
              Array(grouped_by_first.first.first) + merge(parts_lists.map { |p| p.drop(1) })
            end
          else
            [
              grouped_by_first.map do |first_item, sub_parts_lists|
                if first_item.nil?
                  []
                else
                  Array(first_item) + merge(sub_parts_lists.map { |p| p.drop(1) })
                end
              end
            ]
          end
        end

        def flatten_forks(parts_lists)
          result = []
          parts_lists.each do |parts_list|
            next result << parts_list unless parts_list.first.is_a?(Array)

            depth = -1
            depth_check_list = parts_list
            depth += 1 while (depth_check_list = depth_check_list.first) && depth_check_list.is_a?(Array)
            parts_list = parts_list.flatten(depth)
            result.concat(parts_list)
          end
          result
        end
      end
    end
  end
end
