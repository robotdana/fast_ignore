# FastIgnore

[![travis](https://travis-ci.com/robotdana/fast_ignore.svg?branch=master)](https://travis-ci.com/robotdana/fast_ignore)
[![Gem Version](https://badge.fury.io/rb/fast_ignore.svg)](https://rubygems.org/gems/fast_ignore)

This started as a way to quickly and natively ruby-ly parse gitignore files and find matching files.
It's now gained an equivalent includes file functionality, ARGV awareness, and some shebang matching, while still being extremely fast, to be a one-stop file-list for your linter.

Filter a directory tree using a .gitignore file. Recognises all of the [gitignore rules](https://www.git-scm.com/docs/gitignore#_pattern_format)

```ruby
FastIgnore.new(relative: true).sort == `git ls-files`.split("\n").sort
```

## Features

- Fast (faster than using `` `git ls-files`.split("\n") `` for small repos (because it avoids the overhead of ``` `` ```))
- Supports ruby 2.4-2.7 & jruby
- supports all [gitignore rule patterns](https://git-scm.com/docs/gitignore#_pattern_format)
- doesn't require git to be installed
- supports a gitignore-esque "include" patterns. ([`include_rules:`](#include_rules)/[`include_files:`](#include_files))
- supports an expansion of include patterns, expanding and anchoring paths ([`argv_rules:`](#argv_rules))
- supports [matching by shebang](#shebang_rules) rather than filename for extensionless files: `#!:`
- reads .gitignore in all subdirectories
- reads .git/info/excludes
- reads the global gitignore file mentioned in your git config

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'fast_ignore'
```

And then execute:
```sh
$ bundle
```
Or install it yourself as:
```sh
$ gem install fast_ignore
```

## Usage

```ruby
FastIgnore.new.each { |file| puts "#{file} is not ignored by the .gitignore file" }
```

### `#each`, `#map` etc

This yields paths that are _not_ ignored by the gitignore, i.e. the paths that would be returned by `git ls-files`.

A FastIgnore instance is an Enumerable and responds to all Enumerable methods:

```ruby
FastIgnore.new.to_a
FastIgnore.new.map { |file| file.upcase }
```

Like other enumerables, `FastIgnore#each` can return an enumerator:

```ruby
FastIgnore.new.each.with_index { |file, index| puts "#{file}#{index}" }
```

**Warning: Do not change directory (e.g. `Dir.chdir`) in the block.**

### `#allowed?`

To check if a single path is allowed, use
```ruby
FastIgnore.new.allowed?('relative/path')
FastIgnore.new.allowed?('./relative/path')
FastIgnore.new.allowed?('/absolute/path')
FastIgnore.new.allowed?('~/home/path')
```

Relative paths will be considered relative to the [`root:`](#root) directory, not the current directory.

This is aliased as `===` so you can use a FastIgnore instance in case statements.
```ruby
case my_path
when FastIgnore.new
  puts(my_path)
end
```

It's recommended to save the FastIgnore instance to a variable to avoid having to read and parse the gitignore file and gitconfig files repeatedly.

See [Optimising allowed](#optimising_allowed) for ways to make this even faster

**Note: A file must exist at that path and not be a directory for it to be considered allowed.**
Essentially it can be thought of as `` `git ls-files`.include?(path) `` but much faster.
This excludes all directories and all possible path names that don't exist.


### `relative: true`

**Default: false**

When `relative: false`: FastIgnore#each will yield full paths.
When `relative: true`: FastIgnore#each will yield paths relative to the [`root:`](#root) directory

```ruby
FastIgnore.new(relative: true).to_a
```

### `follow_symlinks: true`

**Default: false**

When `follow_symlinks: false`: FastIgnore#each will match git's behaviour and not follow symbolic links.
When `follow_symlinks: true`: FastIgnore#each will check if a symlink points to a directory, and files in linked directories must also match rules using the symlink path as the directory location, not the real directory location.

**This doesn't use the real path for matching or yield or return it.**

```ruby
FastIgnore.new(follow_symlinks: true).to_a
```

### `root:`

**Default: Dir.pwd ($PWD, the current working directory)**

This directory is used for:
- the location of `.git/core/exclude`
- the ancestor of all non-global [automatically loaded `.gitignore` files](#gitignore_false)
- the root directory for array rules ([`ignore_rules:`](#ignore_rules), [`include_rules:`](#include_rules), [`argv_rules:`](#argv_rules)) containing `/`
- the path that [`relative:`](#relative_true) is relative to
- the ancestor of all paths yielded by [`#each`](#each_map_etc)
- the path that [`#allowed?`](#allowed) considers relative paths relative to
- the ancestor of all [`include_files:`](#include_files) and [`ignore_files:`](#ignore_files)

To use a different directory:
```ruby
FastIgnore.new(root: '/absolute/path/to/root').to_a
FastIgnore.new(root: '../relative/path/to/root').to_a
```

A relative root will be found relative to the current working directory when the FastIgnore instance is initialized, and that will be the last time the current working directory is relevant.

**Note: Changes to the current working directory (e.g. with `Dir.chdir`), after initialising a FastIgnore instance, will _not_ affect the FastIgnore instance. `root:` will always be what it was when the instance was initialized, even as a default value.**

### `gitignore:`

**Default: true**

When `gitignore: true`: the .gitignore file in the [`root:`](#root) directory is loaded, plus any .gitignore files in its subdirectories, the global git ignore file as described in git config, and .git/info/exclude. `.git` directories are also excluded to match the behaviour of `git ls-files`.
When `gitignore: false`: no ignore files or git config files are automatically read, and `.git` will not be automatically excluded.

```ruby
FastIgnore.new(gitignore: false).to_a
```

### `ignore_files:`

**This is a list of files in the gitignore format to parse and match paths against, not a list of files to ignore**  If you want an array of files use [`ignore_rules:`](#ignore_rules)

Additional gitignore-style files, either as a path or an array of paths.

You can specify other gitignore-style files to ignore as well.
Missing files will raise an `Errno::ENOENT` error.

Relative paths are relative to the [`root:`](#root) directory.
Absolute paths also need to be within the [`root:`](#root) directory.


```ruby
FastIgnore.new(ignore_files: 'relative/path/to/my/ignore/file').to_a
FastIgnore.new(ignore_files: ['/absolute/path/to/my/ignore/file', '/and/another']).to_a
```

Note: the location of the files will affect rules beginning with or containing `/`.

To avoid raising `Errno::ENOENT` when the file doesn't exist:
```ruby
FastIgnore.new(ignore_files: ['/ignore/file'].select { |f| File.exist?(f) }).to_a
```

### `ignore_rules:`

This can be a string, or an array of strings, and multiline strings can be used with one rule per line.

```ruby
FastIgnore.new(ignore_rules: '.DS_Store').to_a
FastIgnore.new(ignore_rules: ['.git', '.gitkeep']).to_a
FastIgnore.new(ignore_rules: ".git\n.gitkeep").to_a
```

These rules use the [`root:`](#root) argument to resolve rules containing `/`.

### `include_files:`

**This is an array of files in the gitignore format to parse and match paths against, not a list of files to include.**  If you want an array of files use [`include_rules:`](#include_rules).

Building on the gitignore format, FastIgnore also accepts rules to include matching paths (rather than ignoring them).
A rule matching a directory will include all descendants of that directory.

These rules can be provided in files either as absolute or relative paths, or an array of paths.
Relative paths are relative to the [`root:`](#root) directory.
Absolute paths also need to be within the [`root:`](#root) directory.

```ruby
FastIgnore.new(include_files: 'my_include_file').to_a
FastIgnore.new(include_files: ['/absolute/include/file', './relative/include/file']).to_a
```

Missing files will raise an `Errno::ENOENT` error.

To avoid raising `Errno::ENOENT` when the file doesn't exist:
```ruby
FastIgnore.new(include_files: ['include/file'].select { |f| File.exist?(f) }).to_a
```

**Note: All paths checked must not be excluded by any ignore files AND each included by include file separately AND the [`include_rules:`](#include_rules) AND the [`argv_rules:`](#argv_rules). see [Combinations](#combinations) for solutions to using OR.**

### `include_rules:`

Building on the gitignore format, FastIgnore also accepts rules to include matching paths (rather than ignoring them).
A rule matching a directory will include all descendants of that directory.

This can be a string, or an array of strings, and multiline strings can be used with one rule per line.
```ruby
FastIgnore.new(include_rules: %w{my*rule /and/another !rule}, gitignore: false).to_a
```

Rules use the [`root:`](#root) argument to resolve rules containing `/`.

**Note: All paths checked must not be excluded by any ignore files AND each included by [include file](#include_files) separately AND the `include_rules:` AND the [`argv_rules:`](#argv_rules). see [Combinations](#combinations) for solutions to using OR.**

### `argv_rules:`
This is like [`include_rules:`](#include_rules) with additional features meant for dealing with humans and `ARGV` values.

It expands rules that are absolute paths, and paths beginning with `~`, `../` and `./` (with and without `!`).
This means rules beginning with `/` are absolute. Not relative to [`root:`](#root).

Additionally it assumes all rules are relative to the [`root:`](#root) directory (after resolving absolute paths) unless they begin with `*` (or `!*`).

This can be a string, or an array of strings, and multiline strings can be used with one rule per line.

```ruby
FastIgnore.new(argv_rules: ['./a/pasted/path', '/or/a/path/from/stdin', 'an/argument', '*.txt']).to_a
```

**Warning: it will *not* expand e.g. `/../` in the middle of a rule that doesn't begin with any of `~`,`../`,`./`,`/`.**

**Note: All paths checked must not be excluded by any ignore files AND each included by [include file](#include_files) separately AND the [`include_rules:`](#include_rules) AND the `argv_rules:`. see [Combinations](#combinations) for solutions to using OR.**

### shebang rules

Sometimes you need to match files by their shebang/hashbang/etc rather than their path or filename

Rules beginning with `#!:` will match whole words in the shebang line of extensionless files.
e.g.
```gitignore
#!:ruby
```
will match shebang lines: `#!/usr/bin/env ruby` or `#!/usr/bin/ruby` or `#!/usr/bin/ruby -w`

e.g.
```gitignore
#!:bin/ruby
```
will match `#!/bin/ruby` or `#!/usr/bin/ruby` or `#!/usr/bin/ruby -w`
Only exact substring matches are available, There's no special handling of * or / or etc.

These rules can be supplied any way regular rules are, whether in a .gitignore file or files mentioned in [`include_files:`](#include_files) or [`ignore_files:`](#ignore_files) or [`include_rules:`](#include_rules) or [`ignore_rules:`](#ignore_rules) or [`argv_rules:`](#argv_rules)
```ruby
FastIgnore.new(include_rules: ['*.rb', '#!:ruby']).to_a
FastIgnore.new(ignore_rules: ['*.sh', '#!:sh', '#!:bash', '#!:zsh']).to_a
```

**Note: git considers rules like this as a comment and will ignore them.**

## Combinations

In the simplest case a file must be allowed by each ignore file, each include file, and each array of rules. That is, they are combined using `AND`.

To combine files using `OR`, that is, a file may be matched by either file it doesn't have to be referred to in both:
provide the files as strings to [`include_rules:`](#include_rules) or [`ignore_rules:`](#ignore_rules)
```ruby
FastIgnore.new(include_rules: [File.read('/my/path'), File.read('/another/path')])).to_a
```
This does unfortunately lose the file path as the root for rules containing `/`.
If that's important, combine the files in the file system and use [`include_files:`](#include_files) or [`ignore_files:`](#ignore_files) as normal.

To use the additional `ARGV` handling of [`argv_rules:`](#argv_rules) on a file, read the file into the array.

```ruby
FastIgnore.new(argv_rules: ["my/rule", File.read('/my/path')]).to_a
```

This does unfortunately lose the file path as the root `/` and there is no workaround except setting the [`root:`](#root) for the whole FastIgnore instance.

### optimising #allowed?

To avoid unnecessary calls to the filesystem, if your code already knows whether or not it's a directory, or if you're checking shebangs and you have already read the content of the file: use
```ruby
FastIgnore.new.allowed?('relative/path', directory: false, content: "#!/usr/bin/ruby\n\nputs 'ok'\n")
```
This is not required, and if FastIgnore does have to go to the filesystem for this information it's well optimised to only read what is necessary.

## Limitations
- Doesn't know what to do if you change the current working directory inside the [`FastIgnore#each`](#each_map_etc) block.
  So don't do that.

  (It does handle changing the current working directory between [`FastIgnore#allowed?`](#allowed) calls)
- FastIgnore always matches patterns case-insensitively. (git varies by filesystem).
- FastIgnore always outputs paths as literal UTF-8 characters. (git depends on your core.quotepath setting but by default outputs non ascii paths with octal escapes surrounded by quotes).
- Because git looks at its own index objects and FastIgnore looks at the file system there may be some differences between FastIgnore and `git ls-files`
  - Tracked files that were committed before the matching ignore rule was committed will be returned by `git ls-files`, but not by FastIgnore.
  - Untracked files will be returned by FastIgnore, but not by `git ls-files`
  - Deleted files whose deletions haven't been committed will be returned by `git ls-files`, but not by FastIgnore
  - On a case insensitive file system, with files that differ only by case, `git ls-files` will include all case variations, while FastIgnore will only include whichever variation git placed in the file system.
  - FastIgnore is unaware of submodules and just treats them like regular directories. For example: `git ls-files --recurse-submodules` won't use the parent repo's gitignore on a submodule, while FastIgnore doesn't know it's a submodule and will.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/robotdana/fast_ignore.

Some tools that may help:

- `bin/setup`: install development dependencies
- `bundle exec rspec`: run all tests
- `bundle exec rake`: run all tests and linters
- `bin/console`: open a `pry` console with everything required for experimenting
- `bin/ls [argv_rules]`: the equivalent of `git ls-files`
- `bin/prof/ls [argv_rules]`: ruby-prof report for `bin/ls`
- `bin/prof/parse [argv_rules]`: ruby-prof report for parsing root and global gitignore files and any arguments.
- `bin/time [argv_rules]`: the average time for 30 runs of `bin/ls`<br>
  This repo is too small to stress bin/time more than 0.01s, switch to a large repo and find the average time before and after changes.
- `bin/compare`: compare the speed and output of FastIgnore and `git ls-files`.
  (suppressing differences that are because of known [limitations](#limitations))

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
