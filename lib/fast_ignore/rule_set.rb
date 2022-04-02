# frozen_string_literal: true

class FastIgnore
  class RuleSet
    attr_reader :gitignore
    alias_method :gitignore?, :gitignore
    undef :gitignore

    def initialize(rules, allow, gitignore, squash = true)
      @dir_rules = (squash ? squash_rules(rules.reject(&:file_only?)) : rules.reject(&:file_only?)).freeze
      @file_rules = (squash ? squash_rules(rules.reject(&:dir_only?)) : rules.reject(&:dir_only?)).freeze
      @has_shebang_rules = rules.any?(&:shebang?)

      @allowed_recursive = { ::FastIgnore::Candidate.root => true }
      @allow = allow
      @gitignore = gitignore

      freeze unless gitignore?
    end

    def <<(other)
      return unless other

      @has_shebang_rules ||= other.has_shebang_rules
      @dir_rules = squash_rules(@dir_rules + other.dir_rules)
      @file_rules = squash_rules(@file_rules + other.file_rules)
    end

    def allowed_recursive?(candidate)
      @allowed_recursive.fetch(candidate) do
        @allowed_recursive[candidate] =
          allowed_recursive?(candidate.parent) &&
          allowed_unrecursive?(candidate)
      end
    end

    def allowed_unrecursive?(candidate)
      (candidate.directory? ? @dir_rules : @file_rules).reverse_each do |rule|
        return rule.negation? if rule.match?(candidate)
      end

      not @allow
    end

    def squash_rules(rules) # rubocop:disable Metrics/MethodLength
      running_component_rule_size = rules.first&.component_rules_count || 0
      rules.chunk_while do |a, b|
        # a.squashable_type == b.squashable_type
        next true if a.squashable_type == b.squashable_type &&
          (running_component_rule_size + b.component_rules_count <= 40)

        running_component_rule_size = b.component_rules_count
        false
      end.map do |chunk| # rubocop:disable Style/MultilineBlockChain
        first = chunk.first
        next first if chunk.length == 1

        first.squash(chunk)
      end
    end

    def weight
      @dir_rules.length + (@has_shebang_rules ? 10 : 0)
    end

    def empty?
      @dir_rules.empty? && @file_rules.empty?
    end

    protected

    attr_reader :dir_rules
    attr_reader :file_rules
    attr_reader :has_shebang_rules
  end
end
