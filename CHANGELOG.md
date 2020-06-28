# Unreleased
- performance improvements
- add `FastIgnore#to_proc` for no good reason

# v0.13.0
- Attempt to improve documentation structure
- Remove `gitignore: true` raising `Errno::ENOENT` if root:/.gitignore didn't exist. I can't think of a use. Now `gitignore: true` is just the default behaviour.
- Don't ignore `.git` if `gitignore: false`.

# v0.12.1
- Reads all relevant git config files when finding a global .gitignore

# v0.12.0
- Reads all relevant gitignore files (nested .gitignore files, global .gitignore referred to in .gitconfig, and .git/info/exclude)

# v0.11.0
- major performance improvement (use regexp rather than fnmatch)
- optionally pass directory: and content: into allowed? if these are already loaded.

# v0.10.2
- add FastIgnore#=== as an alias for FastIgnore#allowed? so that FastIgnore objects can be used for case statements.
- Fix shebangs in non-pwd-root situations

# v0.10.1
- Add option to follow symlinks (turns out i needed it)
- performance improvements

# v0.10.0
- patterns with middle slashes are anchored to the root (like the gitignore documentation, now that it more clearly explains)
- new shebang pattern (#!:), the previous version was extremely janky.
  - now you can ignore by shebang pattern
- symlinks aren't followed when deciding if a path is a directory or not (this now matches git)
- documentation improvements
- root can be given as a path relative to PWD
- includes with 'a/**/d' now matches a/b/c/d properly

# v0.9.0
- speed improvements, which may break things (Specifically, only using relative paths internally, is about 30% faster (depending on root depth))
- using a `ignore_files:` or `include_files:` that are outside the `root: (default $PWD)` will now raise an error.
- remove deprecated `gitignore:` a path (e.g. `gitignore: '/path/to/gitignore'`). please use `gitignore: false, ignore_files: '/path/to/gitignore'` instead.

# v0.8.3
- fix `ignore_rules` not matching directories when using `include_shebangs:`

# v0.8.2
- fix `include_rules` not matching filenames with no extension when using `include_shebangs:`

# v0.8.1
- `include_shebangs:` can be given non array value

# v0.8.0
- drop support for ruby 2.3. My plan is to only support supported ruby versions
- add coverage to the pipeline. removed some methods, added some tests, and now we have 100% test coverage
- deprecate using `gitignore: '/path/to/gitignore'`. please use `gitignore: false, ignore_files: '/path/to/gitignore'` instead.

# v0.7.0
- add `include_shebangs:` which filters by shebangs

# v0.6.0
- nicer argv handling
  - add `argv_rules:` option, which resolves paths and considers everything that doesn't start with a `*` to start with a `/`
- combine the different includes methods and files using AND
- slightly more realistic version comparison just in case someone releases ruby 2.10
- can be run with --disable-gems
- `.allowed?` now more exactly matches `.each`, it returns false for directories and unreadable files.

# v0.5.2
- performance improvements

# v0.5.1
- restore `.allowed?`. now i have tests for it. oops

# v0.5.0
- remove deprecated `:rules` and `:files` arguments
- ! is now evaluated in sequence for include_rules
- it's a big refactor, sorry if i broke something
- some performance improvements

# v0.4.1
- oops i did a regexp wrong

# v0.4.0
- include_rules support
- to make room for this, `:rules` and `:files` keyword arguments are deprecated.
  Please use `:ignore_rules` and `:ignore_files` instead.

# v0.3.3
- some performance improvements. maybe

# v0.3.2
- handle soft links to nowhere

# v0.3.1
- upgrade rubocop version requirement to avoid github security warning

# v0.3.0
- Supports 2.3 - 2.6

# v0.2.0
- Considers rules relative to the location of the gitignore file instead of just relative to PWD
- Can override the path to the gitignore file, using `FastIgnore.new(gitignore: path)`
- Mention FastIgnore#allowed? in the documentation.

# v0.1.0
Initial Release
