# frozen_string_literal: true

class FastIgnore
  module PathListMethods
    # def allowed?(path, directory: nil, content: nil, exists: nil, include_directories: false)
    #   rule_set.query.allowed?(
    #     path,
    #     directory: directory,
    #     content: content,
    #     exists: exists,
    #     include_directories: include_directories
    #   )
    # end
    # alias_method :===, :allowed?

    # def to_proc
    #   method(:allowed?).to_proc
    # end

    # def each(root: '.', &block)
    #   return enum_for(:each, root: root) unless block

    #   rule_set.query.each(PathExpander.expand_dir(root), '', rule_set, &block)
    # end

    def gitignore(root: nil)
      ignore(root: root, append: :gitignore)
        .ignore(from_file: ::FastIgnore::GlobalGitignore.path(root: root), root: root, append: :gitignore)
        .ignore(from_file: './.git/info/exclude', root: root, append: :gitignore)
        .ignore(from_file: './.gitignore', root: root, append: :gitignore)
        .ignore('.git', root: '/')
        .walker(::FastIgnore::Walkers::GitignoreCollectingFileSystem)
    end

    def walker(walker)
      new(rule_set.new(walker: walker))
    end

    def ignore(*patterns, from_file: nil, format: nil, root: nil, append: false)
      new_rule_set(
        *patterns,
        from_file: from_file,
        format: format,
        root: root,
        append: append
      )
    end

    def only(*patterns, from_file: nil, format: nil, root: nil, append: false)
      new_rule_set(
        *patterns,
        from_file: from_file,
        format: format,
        root: root,
        append: append,
        allow: true
      )
    end

    private

    def new_rule_set(*patterns, from_file: nil, format: nil, root: nil, allow: false, append: nil) # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists
      new(
        if append
          if rule_set.appendable?(append)
            rule_set.append(
              append, *patterns, from_file: from_file, format: format, root: root
            )
          else
            rule_set.new(
              ::FastIgnore::AppendablePatterns.new(
                *patterns, from_file: from_file, format: format, root: root, allow: allow
              ),
              label: append
            )
          end
        else
          rule_set.new(
            ::FastIgnore::Patterns.new(
              *patterns, from_file: from_file, format: format, root: root, allow: allow
            )
          )
        end
      )
    end
  end
end
