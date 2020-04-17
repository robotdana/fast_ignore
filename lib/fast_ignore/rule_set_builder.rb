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
      argv_rules: nil,
      and_no_ext: false
    )
      rule_sets = [
        from_array(ignore_rules, root: root),
        *from_files(ignore_files, project_root: root),
        from_array('.git', root: root),
        from_gitignore_arg(gitignore, root: root),
        from_array(include_rules, root: root, allow: true, and_no_ext: and_no_ext),
        *from_files(include_files, allow: true, project_root: root, and_no_ext: and_no_ext),
        from_array(argv_rules, root: root, allow: true, expand_path: true, and_no_ext: and_no_ext)
      ]

      rule_sets.compact!
      rule_sets.reject!(&:empty?)
      if and_no_ext && rule_sets.none?(&:allow?)
        rule_sets << ::FastIgnore::RuleSet.new(project_root: root, allow: true, and_no_ext: and_no_ext)
      end
      rule_sets.sort_by!(&:length)
      rule_sets
    end

    def self.from_file(filename, allow: false, project_root: Dir.pwd, and_no_ext: false)
      filename = ::File.expand_path(filename)
      root = ::File.dirname(filename)
      rule_set = ::FastIgnore::RuleSet.new(project_root: project_root, allow: allow, and_no_ext: and_no_ext)

      ::IO.foreach(filename) do |rule_string|
        parse_rules(rule_string, allow: allow, rule_set: rule_set, root: root)
      end

      rule_set
    end

    def self.from_files(files, allow: false, project_root: Dir.pwd, and_no_ext: false)
      Array(files).map do |file|
        from_file(file, allow: allow, project_root: project_root, and_no_ext: and_no_ext)
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

    def self.from_array(rules, allow: false, expand_path: false, root: Dir.pwd, and_no_ext: false)
      rules = Array(rules)
      return if rules.empty?

      rule_set = ::FastIgnore::RuleSet.new(project_root: root, allow: allow, and_no_ext: and_no_ext)

      rules.each do |rule_string|
        rule_string.to_s.each_line do |rule_line|
          parse_rules(rule_line, rule_set: rule_set, allow: allow, root: root, expand_path: expand_path)
        end
      end

      rule_set
    end

    def self.parse_rules(rule_line, rule_set:, allow: false, root: Dir.pwd, expand_path: false)
      ::FastIgnore::RuleParser.new_rule(
        rule_line,
        rule_set: rule_set,
        allow: allow,
        root: root,
        expand_path: expand_path
      )
    end
  end
end
