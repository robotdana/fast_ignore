# frozen_string_literal: true
require_relative 'rule'

class FastIgnore
  class RuleParser
    unless ::RUBY_VERSION >= '2.4'
      require_relative 'backports/match'
      using ::FastIgnore::Backports::Match
    end

    # rule or nil
    def self.new_rule(rule, root:, expand_path: false)
      rule = strip(rule)
      rule, dir_only = extract_dir_only(rule)
      rule = expand_path(rule, root) if expand_path

      return if skip?(rule)

      rule, negation = extract_negation(rule)

      rule = "#{root}#{prefix(rule)}#{rule}"

      ::FastIgnore::Rule.new(rule, dir_only, negation)
    end

    private

    def self.extract_negation(rule)
      return [rule, false] unless rule.start_with?('!')

      [rule[1..-1], true]
    end

    def self.extract_dir_only(rule)
      return [rule, false] unless rule.end_with?('/')

      [rule[0..-2], true]
    end

    def self.strip(rule)
      rule = rule.chomp
      rule = rule.rstrip unless rule.end_with?('\\ ')
      rule
    end

    def self.prefix(rule)
      if rule.start_with?('/')
        ''
      elsif rule.end_with?('/**') || rule.include?('/**/')
        '/'
      else
        '/**/'
      end
    end

    def self.expand_path(rule, root)
      if rule.match?(%r{^(?:[~/]|\.{1,2}/)})
        ::File.expand_path(rule).delete_prefix(root)
      else
        rule
      end
    end

    def self.skip?(rule)
      empty?(rule) || comment?(rule)
    end

    def self.empty?(rule)
      rule.empty?
    end

    def self.comment?(rule)
      rule.start_with?('#')
    end
  end
end
