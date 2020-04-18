# FastIgnore

[![travis](https://travis-ci.org/robotdana/fast_ignore.svg?branch=master)](https://travis-ci.org/robotdana/fast_ignore)

Filter a directory tree using a .gitignore file. Recognises all of the [gitignore rules](https://www.git-scm.com/docs/gitignore#_pattern_format) ([except one](#known-issues))

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

Like many other enumerables, `FastIgnore#each` can return an enumerator

```ruby
FastIgnore.new.each.with_index { |file, index| puts "#{file}#{index}" }
```

By default, FastIgnore will return full paths. To return paths relative to the current working directory, use:

```ruby
FastIgnore.new(relative: true).to_a
```

You can specify other gitignore-style files to ignore as well. Missing files will raise an `Errno::ENOENT` error.

```ruby
FastIgnore.new(ignore_files: '/absolute/path/to/my/ignore/file').to_a
FastIgnore.new(ignore_files: ['/absolute/path/to/my/ignore/file', '/and/another']).to_a
```

You can also supply an array of rule strings.

```ruby
FastIgnore.new(ignore_rules: '.DS_Store').to_a
FastIgnore.new(ignore_rules: ['.git', '.gitkeep']).to_a
```

To use only another ignore file or an array of rules, and not even try to load a gitignore file:
```ruby
FastIgnore.new(ignore_files: '/absolute/path/to/my/ignore/file', gitignore: false)
FastIgnore.new(ignore_rules: %w{my*rule /and/another !rule}, gitignore: false)
```

By default, FastIgnore will look in the directory the script is run in (`PWD`) for a gitignore file. If it's somewhere else:
```ruby
FastIgnore.new(ignore_file: '/absolute/path/to/.gitignore', gitignore: false).to_a
```
Note that the location of the .gitignore file will affect rules beginning with `/` or ending in `/**`

To raise an `Errno::ENOENT` error if the .gitignore file is not found use:
```ruby
FastIgnore.new(gitignore: true).to_a
```

To filter by extensionless files shebang/hashbang/etc:
```ruby
FastIgnore.new(include_rules: '*.rb', include_shebangs: 'ruby').to_a
FastIgnore.new(include_rules: '*.sh', include_shebangs: ['sh', 'bash', 'zsh']).to_a
```

To check if a single file is allowed, use
```ruby
FastIgnore.new.allowed?('relative/path')
FastIgnore.new.allowed?('./relative/path')
FastIgnore.new.allowed?('/absolute/path')
FastIgnore.new.allowed?('~/home/path')
```

### Using an includes list.

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
FastIgnore.new(include_files: '/absolute/path/to/my/include/file', gitignore: false)
FastIgnore.new(include_rules: %w{my*rule /and/another !rule}, gitignore: false)
```

There is an additional argument meant for dealing with humans and `ARGV` values.

```ruby
FastIgnore.new(argv_rules: ['./a/pasted/path', '/or/a/path/from/stdin', 'an/argument', '*.txt'])
```

It resolves absolute paths, and paths beginning with `~`, `../` and `./` (with and without `!`)
It assumes all rules are anchored unless they begin with `*` or `!*`.

Note: it will *not* resolve e.g. `/../` in the middle of a rule that doesn't begin with any of `~`,`../`,`./`,`/`.

## Combinations

In the simplest case a file must be allowed by each ignore file, each include file, and each array of rules. That is, they are combined using AND.

To combine files using `OR`, that is, a file may be included by either file it doesn't have to be referred to in both:

```ruby
FastIgnore.new(include_files: StringIO.new([File.read('/my/path'), File.read('/another/path')]).join("\n"))
```

To use the additional ARGV handling rules mentioned above for files

```ruby
FastIgnore.new(argv_rules: ["my/rule", File.read('/my/path')])
```

## Known issues
- Doesn't take into account project excludes in `.git/info/exclude`
- Doesn't take into account globally ignored files in `git config core.excludesFile`.
- Doesn't follow this rule in the gitignore documentation because I don't understand what it means that isn't covered by other rules:

  > [If the pattern does not contain a slash /, Git treats it as a shell glob pattern and checks for a match against the pathname relative to the location of the `.gitignore` file (relative to the toplevel of the work tree if not from a `.gitignore` file)](https://www.git-scm.com/docs/gitignore#_pattern_format)

  if someone can explain it with examples [make an issue please](https://github.com/robotdana/fast_ignore/issues/new)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/robotdana/fast_ignore.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
