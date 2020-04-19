# frozen_string_literal: true

class FastIgnore
  class RuleSetBuilder
    def self.from_args( # rubocop:disable Metrics/ParameterLists, Metrics/MethodLength
      root: Dir.pwd,
      ignore_rules: nil,
      ignore_files: nil,
      gitignore: :auto,
      include_rules: nil,
      include_files: nil,
      argv_rules: nil
    )
      rule_sets = [
        from_array(ignore_rules, root: root),
        *from_files(ignore_files, project_root: root),
        from_array('.git', root: root),
        from_gitignore_arg(gitignore, root: root),
        from_array(include_rules, root: root, allow: true),
        *from_files(include_files, allow: true, project_root: root),
        from_array(argv_rules, root: root, allow: true, expand_path: true)
      ]

      rule_sets.compact!
      rule_sets.reject!(&:empty?)
      rule_sets.sort_by!(&:length)
      rule_sets
    end

    def self.from_file(filename, allow: false, project_root: Dir.pwd)
      filename = ::File.expand_path(filename)
      root = ::File.dirname(filename) + '/'
      raise FastIgnore::Error, "#{filename} is not within #{project_root}" unless filename.start_with?(project_root)

      root = root.delete_prefix(project_root)
      rule_set = ::FastIgnore::RuleSet.new(allow: allow)

      ::IO.foreach(filename) do |rule_string|
        parse_rules(rule_string, allow: allow, rule_set: rule_set, root: project_root, file_root: root)
      end

      rule_set.freeze
    end

    def self.from_files(files, allow: false, project_root: Dir.pwd)
      Array(files).map do |file|
        from_file(file, allow: allow, project_root: project_root)
      end
    end

    def self.from_gitignore_arg(gitignore, root: Dir.pwd) # rubocop:disable Metrics/MethodLength
      default_path = ::File.join(root, '.gitignore')
      case gitignore
      when :auto
        from_file(default_path, project_root: root) if ::File.exist?(default_path)
      when true
        from_file(default_path, project_root: root)
      when false
        nil
      else
        warn 'Deprecation warning! supplying gitignore file path directly is deprecated. '\
          'Please use gitignore: false and add your path to the ignore_files array'
        from_file(gitignore, project_root: root)
      end
    end

    def self.from_array(rules, allow: false, expand_path: false, root: Dir.pwd)
      rules = Array(rules)
      return if rules.empty?

      rule_set = ::FastIgnore::RuleSet.new(allow: allow)

      rules.each do |rule_string|
        rule_string.to_s.each_line do |rule_line|
          parse_rules(rule_line, rule_set: rule_set, allow: allow, root: root, expand_path: expand_path)
        end
      end

      rule_set.freeze
    end

    def self.parse_rules(rule_line, rule_set:, allow: false, root: Dir.pwd, expand_path: false, file_root: nil) # rubocop:disable Metrics/ParameterLists
      ::FastIgnore::RuleParser.new_rule(
        rule_line,
        rule_set: rule_set,
        allow: allow,
        root: root,
        expand_path: expand_path,
        file_root: file_root
      )
    end
  end
end
