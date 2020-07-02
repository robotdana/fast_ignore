# frozen_string_literal: true

class FastIgnore
  class ShebangRule
    attr_reader :negation
    alias_method :negation?, :negation
    undef :negation

    attr_reader :rule

    attr_reader :file_path_pattern

    attr_reader :squashable_type

    def squash(rules)
      ::FastIgnore::ShebangRule.new(::Regexp.union(rules.map(&:rule)).freeze, negation?, file_path_pattern)
    end

    def initialize(rule, negation, file_path_pattern)
      @rule = rule
      @negation = negation
      @file_path_pattern = file_path_pattern

      @squashable_type = (negation ? 13 : 12) + file_path_pattern.object_id

      freeze
    end

    def file_only?
      true
    end

    def dir_only?
      false
    end

    # :nocov:
    def inspect
      allow_fragment = 'allow ' if @negation
      in_fragment = " in #{@file_path_pattern}" if @file_path_pattern
      "#<ShebangRule #{allow_fragment}#!:#{@rule.to_s[15..-4]}#{in_fragment}>"
    end
    # :nocov:

    def match?(path, full_path, filename, content)
      return false if filename.include?('.')
      return false unless (not @file_path_pattern) || @file_path_pattern.match?(path)

      (content || first_line(full_path))&.match?(@rule)
    end

    def shebang?
      true
    end

    private

    def first_line(path) # rubocop:disable Metrics/MethodLength
      file = ::File.new(path)
      first_line = new_fragment = file.sysread(64)
      if first_line.start_with?('#!')
        until new_fragment.include?("\n")
          new_fragment = file.sysread(64)
          first_line += new_fragment
        end
      else
        file.close
        return
      end
      file.close
      first_line
    rescue ::EOFError, ::SystemCallError
      # :nocov:
      file&.close
      # :nocov:
      first_line
    end
  end
end
