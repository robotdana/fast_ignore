# frozen_string_literal: true

class FastIgnore
  class RuleSet
    attr_reader :gitignore
    alias_method :gitignore?, :gitignore
    undef :gitignore

    def initialize(rules, allow, gitignore, _squash = true)
      # @dir_rules = (squash ? squash_rules(rules.reject(&:file_only?)) : rules.reject(&:file_only?)).freeze
      # @file_rules = (squash ? squash_rules(rules.reject(&:dir_only?)) : rules.reject(&:dir_only?)).freeze
      @dir_rules = rules.reject(&:file_only?).freeze
      @file_rules = rules.reject(&:dir_only?).freeze

      @has_shebang_rules = rules.any?(&:shebang?)

      @allowed_recursive = { '.' => true, '' => true, nil => true }
      @allow = allow
      @gitignore = gitignore

      freeze unless gitignore?
    end

    def <<(other)
      return unless other

      @has_shebang_rules ||= other.has_shebang_rules
      # @dir_rules = squash_rules(@dir_rules + other.dir_rules)
      # @file_rules = squash_rules(@file_rules + other.file_rules)
      @dir_rules = (@dir_rules + other.dir_rules).freeze
      @file_rules = (@file_rules + other.file_rules).freeze
    end

    def allowed_recursive?(root_candidate, root)
      relative_candidate = root_candidate.relative_candidate(root)
      @allowed_recursive.fetch(relative_candidate&.relative_path) do
        @allowed_recursive[relative_candidate&.relative_path] =
          allowed_recursive?(root_candidate.parent, root) &&
          allowed_unrecursive?(root_candidate, root)
      end
    end

    def allowed_unrecursive?(root_candidate, root)
      relative_candidate = root_candidate.relative_candidate(root)
      val = match?(relative_candidate)

      if val
        val == :negated
      else
        not @allow
      end
    end

    def match?(relative_candidate)
      (relative_candidate.directory? ? @dir_rules : @file_rules).reverse_each do |rule|
        val = rule.match?(relative_candidate)
        return val if val
      end

      false
    end

    # def squash_rules(rules)
    #   running_component_rule_size = rules.first&.component_rules_count || 0
    #   rules.chunk_while do |a, b|
    #     # a.squashable_type == b.squashable_type
    #     next true if a.squashable_type == b.squashable_type &&
    #       (running_component_rule_size + b.component_rules_count <= 40)

    #     running_component_rule_size = b.component_rules_count
    #     false
    #   end.map do |chunk|
    #     first = chunk.first
    #     next first if chunk.length == 1

    #     first.squash(chunk)
    #   end
    # end

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
