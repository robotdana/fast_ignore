# frozen_string_literal: true

class FastIgnore
  class RuleSetBuilder
    def self.from_args( # rubocop:disable Metrics/ParameterLists, Metrics/MethodLength
      root:,
      ignore_rules:,
      ignore_files:,
      gitignore:,
      include_rules:,
      include_files:,
      argv_rules:
    )
      rule_sets = [
        from_array(ignore_rules),
        *from_files(ignore_files, project_root: root),
        from_array('.git'),
        from_gitignore_arg(gitignore, project_root: root),
        from_array(include_rules, allow: true),
        *from_files(include_files, allow: true, project_root: root),
        from_array(argv_rules, allow: true, expand_path: root)
      ]

      rule_sets.compact!
      rule_sets.reject!(&:empty?)
      rule_sets.sort_by!(&:length)
      rule_sets
    end

    def self.from_file(filename, project_root:, allow: false)
      filename = ::File.expand_path(filename)
      root = ::File.dirname(filename) + '/'
      raise FastIgnore::Error, "#{filename} is not within #{project_root}" unless filename.start_with?(project_root)

      root = root.delete_prefix(project_root)
      rule_set = ::FastIgnore::RuleSet.new(allow: allow)

      ::IO.foreach(filename) do |rule_string|
        parse_rules(rule_string, allow: allow, rule_set: rule_set, file_root: root)
      end

      rule_set.freeze
    end

    def self.from_files(files, project_root:, allow: false)
      Array(files).map do |file|
        from_file(file, allow: allow, project_root: project_root)
      end
    end

    def self.from_gitignore_arg(gitignore, project_root:) # rubocop:disable Metrics/MethodLength
      default_path = ::File.join(project_root, '.gitignore')
      case gitignore
      when :auto
        from_file(default_path, project_root: project_root) if ::File.exist?(default_path)
      when true
        from_file(default_path, project_root: project_root)
      when false
        nil
      else
        warn 'Deprecation warning! supplying gitignore file path directly is deprecated. '\
          'Please use gitignore: false and add your path to the ignore_files array'
        from_file(gitignore, project_root: project_root)
      end
    end

    def self.from_array(rules, allow: false, expand_path: false)
      rules = Array(rules)
      return if rules.empty?

      rule_set = ::FastIgnore::RuleSet.new(allow: allow)

      rules.each do |rule_string|
        rule_string.to_s.each_line do |rule_line|
          parse_rules(rule_line, rule_set: rule_set, allow: allow, expand_path: expand_path)
        end
      end

      rule_set.freeze
    end

    def self.parse_rules(rule_line, rule_set:, allow: false, expand_path: false, file_root: nil)
      ::FastIgnore::RuleParser.new_rule(
        rule_line,
        rule_set: rule_set,
        allow: allow,
        expand_path: expand_path,
        file_root: file_root
      )
    end
  end
end
