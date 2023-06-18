# frozen_string_literal: true

class PathList
  class Rule
    def initialize
      @negated = nil
      @start = nil # :start_of_path, :start_of_name, :substring
      @end = nil # :end_of_path, :end_of_name, :substring
      @dir_only = nil
      @parts = [] # [string, re, :any_name, :many_name]
      @invalid = false
    end

    def empty?
      @parts.empty?
    end

    def dir_only!
      @dir_only = true
    end

    def dir_only?
      @dir_only
    end

    def invalid!
      @invalid = true
    end

    def invalid?
      @invalid
    end

    def negated!
      @negated
    end

    def negated?
      @negated
    end
  end
end
