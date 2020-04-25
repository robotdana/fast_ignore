# FastIgnore

[![travis](https://travis-ci.org/robotdana/fast_ignore.svg?branch=master)](https://travis-ci.org/robotdana/fast_ignore)

This started as a way to quickly and natively ruby-ly parse gitignore files and find matching files.
It's now gained an equivalent includes file functionality, ARGV awareness, and some shebang matching, while still being extremely fast, to be a one-stop file-list for your linter.

Filter a directory tree using a .gitignore file. Recognises all of the [gitignore rules](https://www.git-scm.com/docs/gitignore#_pattern_format)

```ruby
FastIgnore.new(relative: true).sort == `git ls-files`.split("\n").sort
```

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

The FastIgnore object is an enumerable and responds to all Enumerable methods

```ruby
FastIgnore.new.to_a
FastIgnore.new.map { |file| file.upcase }
```

Like other enumerables, `FastIgnore#each` can return an enumerator

```ruby
FastIgnore.new.each.with_index { |file, index| puts "#{file}#{index}" }
```

### `#allowed?`

To check if a single file is allowed, use
```ruby
FastIgnore.new.allowed?('relative/path')
FastIgnore.new.allowed?('./relative/path')
FastIgnore.new.allowed?('/absolute/path')
FastIgnore.new.allowed?('~/home/path')
```

This is aliased as `===` so you can use the FastIgnore object in case statements.
```ruby
case my_path
when FastIgnore.new then puts my_path
end
```

It's recommended to memoize the FastIgnore.new object somehow to avoid having to parse the gitignore file repeatedly.

### `relative: true`
By default, FastIgnore.each will yield full paths. To yield paths relative to the current working directory, or if supplied, [`root:`](#root), use:

```ruby
FastIgnore.new(relative: true).to_a
```

### `follow_symlinks: true`
By default, FastIgnore will match git's behaviour and not follow symbolic links.
To make it follow symlinks, use:

```ruby
FastIgnore.new(follow_symlinks: true).to_a
```

### `root:`

By default, root is PWD (the current working directory)
This directory is used for:
- looking for .gitignore files
- as the root directory for array rules starting with `/` or ending with `/**`
- and the path that relative is relative to
- which files get checked

To use a different directory:
```ruby
FastIgnore.new(root: '/absolute/path/to/root').to_a
FastIgnore.new(root: '../relative/path/to/root').to_a
```

### `gitignore:`

By default, the .gitignore file in root directory is loaded.
To not do this use
```ruby
FastIgnore.new(gitignore: false).to_a
```

To raise an `Errno::ENOENT` error if the .gitignore file is not found use:
```ruby
FastIgnore.new(gitignore: true).to_a
```

If the gitignore file is somewhere else
```ruby
FastIgnore.new(ignore_file: '/absolute/path/to/.gitignore', gitignore: false).to_a
```
Note that the location of the .gitignore file will affect rules beginning with `/` or ending in `/**`

### `ignore_files:`
You can specify other gitignore-style files to ignore as well.
Missing files will raise an `Errno::ENOENT` error.

```ruby
FastIgnore.new(ignore_files: '/absolute/path/to/my/ignore/file').to_a
FastIgnore.new(ignore_files: ['/absolute/path/to/my/ignore/file', '/and/another']).to_a
```

### `ignore_rules:`
You can also supply an array of rule strings.

```ruby
FastIgnore.new(ignore_rules: '.DS_Store').to_a
FastIgnore.new(ignore_rules: ['.git', '.gitkeep']).to_a
FastIgnore.new(ignore_rules: ".git\n.gitkeep").to_a
```

### `include_files:` and `include_rules:`

Building on the gitignore format, FastIgnore also accepts a list of allowed or included files.

```gitignore
# a line like this means any files named foo will be included
# as well as any files within directories named foo
foo
# a line beginning with a slash will be anything in a directory that is a child of the $PWD
/foo
# a line ending in a slash will will include any files in any directories named foo
# but not any files named foo
foo/
fo*
!foe
# otherwise this format deals with !'s, *'s and ?'s and etc as you'd expect from gitignore.
```

These can be passed either as files or as an array or string rules
```ruby
FastIgnore.new(include_files: '/absolute/path/to/my/include/file', gitignore: false).to_a
FastIgnore.new(include_rules: %w{my*rule /and/another !rule}, gitignore: false).to_a
```

There is an additional argument meant for dealing with humans and `ARGV` values.

```ruby
FastIgnore.new(argv_rules: ['./a/pasted/path', '/or/a/path/from/stdin', 'an/argument', '*.txt']).to_a
```

It resolves absolute paths, and paths beginning with `~`, `../` and `./` (with and without `!`)
It assumes all rules are anchored unless they begin with `*` or `!*`.

Note: it will *not* resolve e.g. `/../` in the middle of a rule that doesn't begin with any of `~`,`../`,`./`,`/`.

### shebang rules

Sometimes you need to match files by their shebang rather than their path or filename

To match extensionless files by shebang/hashbang/etc:

Lines beginning with `#!:` will match whole words in the shebang line of extensionless files.
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
Currently only exact substring matches are available, There's no special handling of * or / or etc.

```ruby
FastIgnore.new(include_rules: ['*.rb', '#!:ruby']).to_a
FastIgnore.new(ignore_rules: ['*.sh', '#!:sh', '#!:bash', '#!:zsh']).to_a
```

## Combinations

In the simplest case a file must be allowed by each ignore file, each include file, and each array of rules. That is, they are combined using AND.

To combine files using `OR`, that is, a file may be matched by either file it doesn't have to be referred to in both:
provide the files as strings to `include_rules:` or `ignore_rules:`
```ruby
FastIgnore.new(include_rules: [File.read('/my/path'), File.read('/another/path')])).to_a
```
This does unfortunately lose the file path as the root for `/` and `/**` rules.
If that's important, combine the files in the file system and use `include_files:` or `ignore_files:` as normal.

To use the additional ARGV handling rules mentioned above for files, read the file into the array as a string.

```ruby
FastIgnore.new(argv_rules: ["my/rule", File.read('/my/path')]).to_a
```

This does unfortunately lose the file path as the root for `/` and `/**` rules.

## Known issues
- Doesn't take into account project excludes in `.git/info/exclude`
- Doesn't take into account globally ignored files in `git config core.excludesFile`.
- Doesn't know what to do if you change the current working directory inside the `FastIgnore#each` block.
  So don't do that.

  (It does handle changing the current working directory between `FastIgnore#allowed?` calls.)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/robotdana/fast_ignore.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
