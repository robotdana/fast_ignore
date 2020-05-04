# frozen_string_literal: true

class FastIgnore
  class RuleSet
    attr_reader :gitignore
    alias_method :gitignore?, :gitignore
    undef :gitignore

    def initialize(rules, allow, gitignore)
      @dir_rules = squash_rules(rules.reject(&:file_only?)).freeze
      @file_rules = squash_rules(rules.reject(&:dir_only?)).freeze
      @any_not_anchored = rules.any?(&:unanchored?)
      @has_shebang_rules = rules.any?(&:shebang)

      @allowed_recursive = { '.' => true }
      @allow = allow
      @gitignore = gitignore

      freeze unless gitignore?
    end

    def <<(other)
      return unless other

      @any_not_anchored ||= other.any_not_anchored
      @has_shebang_rules ||= other.has_shebang_rules
      @dir_rules += other.dir_rules
      @file_rules += other.file_rules
    end

    def allowed_recursive?(relative_path, dir, full_path, filename, content = nil)
      @allowed_recursive.fetch(relative_path) do
        @allowed_recursive[relative_path] =
          allowed_recursive?(::File.dirname(relative_path), true, nil, nil, nil) &&
          allowed_unrecursive?(relative_path, dir, full_path, filename, content)
      end
    end

    def allowed_unrecursive?(relative_path, dir, full_path, filename, content)
      (dir ? @dir_rules : @file_rules).reverse_each do |rule|
        return rule.negation? if rule.match?(relative_path, full_path, filename, content)
      end

      (not @allow) || (dir && @any_not_anchored)
    end

    def squash_rules(rules)
      out = rules.chunk_while { |a, b| a.type == b.type }.map do |chunk|
        next chunk.first if chunk.length == 1

        chunk.first.class.new(Regexp.union(chunk.map(&:rule)), chunk.first.negation?)
      end

      out
    end

    def weight
      @dir_rules.length + (@has_shebang_rules ? 10 : 0)
    end

    def empty?
      @dir_rules.empty? && @file_rules.empty?
    end

    protected

    attr_reader :dir_rules, :file_rules, :any_not_anchored, :has_shebang_rules
  end
end
