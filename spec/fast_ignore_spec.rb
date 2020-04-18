# frozen_string_literal: true

require 'pathname'

RSpec::Matchers.define(:allow) do |*expected|
  match do |actual|
    expect(actual.to_a).to include(*expected)
    if actual.respond_to?(:allowed?)
      expected.each do |path|
        expect(actual).to be_allowed(path)
      end
    end

    true
  end
end
RSpec::Matchers.define_negated_matcher(:exclude, :include)
RSpec::Matchers.define(:disallow) do |*expected|
  match do |actual|
    expect(actual.to_a).to exclude(*expected)
    if actual.respond_to?(:allowed?)
      expected.each do |path|
        expect(actual).not_to be_allowed(path)
      end
    end

    true
  end
end

RSpec::Matchers.define(:allow_exactly) do |*expected|
  match do |actual|
    expect(actual.to_a).to contain_exactly(*expected)

    if actual.respond_to?(:allowed?)
      expected.each do |path|
        expect(actual).to be_allowed(path)
      end
    end

    true
  end
end

RSpec.describe FastIgnore do
  it 'has a version number' do
    expect(FastIgnore::VERSION).not_to be nil
  end

  shared_examples 'the gitignore documentation:' do
    describe 'A blank line matches no files, so it can serve as a separator for readability.' do
      before { create_file_list 'foo', 'bar', 'baz' }

      it 'ignores nothing when gitignore is empty' do
        gitignore ''

        expect(subject).to allow('foo', 'bar', 'baz')
      end

      it 'ignores nothing when gitignore only contains newlines' do
        gitignore <<~GITIGNORE


        GITIGNORE

        expect(subject).to allow('foo', 'bar', 'baz')
      end

      it 'ignores mentioned files when gitignore includes newlines' do
        gitignore <<~GITIGNORE

          foo
          bar

        GITIGNORE

        expect(subject).to allow('baz').and(disallow('foo', 'bar'))
      end
    end

    describe 'A line starting with # serves as a comment.' do
      before { create_file_list '#foo', 'foo' }

      it "doesn't ignore files whose names look like a comment" do
        gitignore <<~GITIGNORE
          #foo
          foo
        GITIGNORE

        expect(subject).to allow('#foo').and(disallow('foo'))
      end

      describe 'Put a backslash ("\") in front of the first hash for patterns that begin with a hash' do
        it 'ignores files whose names look like a comment when prefixed with a backslash' do
          gitignore <<~GITIGNORE
            \\#foo
          GITIGNORE

          expect(subject).to allow('foo').and(disallow('#foo'))
        end
      end
    end

    describe 'Trailing spaces are ignored unless they are quoted with backslash ("\")' do
      before { create_file_list 'foo', 'foo ', 'foo  ' }

      it 'ignores trailing spaces in the gitignore file' do
        gitignore 'foo  '

        expect(subject).to allow('foo  ', 'foo ').and(disallow('foo'))
      end

      it "doesn't ignore trailing spaces if there's a backslash" do
        gitignore "foo \\ \n"

        expect(subject).to allow('foo', 'foo ').and(disallow('foo  '))
      end

      it "doesn't ignore trailing spaces if there's a backslash before every space" do
        gitignore "foo\\ \\ \n"

        expect(subject).to allow('foo', 'foo ').and(disallow('foo  '))
      end
    end

    describe 'If the pattern ends with a slash, it is removed for the purpose of the following description' do
      describe 'but it would only find a match with a directory' do
        # In other words, foo/ will match a directory foo and paths underneath it,
        # but will not match a regular file or a symbolic link foo
        # (this is consistent with the way how pathspec works in general in Git).

        before { create_file_list 'bar/foo', 'foo/bar' }

        it 'ignores directories but not files that match patterns ending with /' do
          gitignore <<~GITIGNORE
            foo/
          GITIGNORE

          expect(subject).to allow('bar/foo').and(disallow('foo/bar'))
        end
      end
    end

    describe 'An optional prefix "!" which negates the pattern' do
      describe 'any matching file excluded by a previous pattern will become included again.' do
        before { create_file_list 'foo', 'foe' }

        it 'includes previously excluded files' do
          gitignore <<~GITIGNORE
            fo*
            !foo
          GITIGNORE

          expect(subject).to allow('foo').and(disallow('foe'))
        end

        it 'is read in order' do
          gitignore <<~GITIGNORE
            !foo
            fo*
          GITIGNORE

          expect(subject).to disallow('foe', 'foo')
        end

        it 'has no effect if not negating anything' do
          gitignore <<~GITIGNORE
            !foo
          GITIGNORE
          expect(subject).to allow('foe', 'foo')
        end
      end

      describe 'It is not possible to re-include a file if a parent directory of that file is excluded' do
        # Git doesn't list excluded directories for performance reasons
        # so any patterns on contained files have no effect no matter where they are defined
        before { create_file_list 'foo/bar', 'foo/foo', 'bar/bar' }

        it "doesn't include files inside previously excluded directories" do
          gitignore <<~GITIGNORE
            foo
            !foo/bar
          GITIGNORE

          expect(subject).to allow('bar/bar').and(disallow('foo/bar', 'foo/foo'))
        end
      end

      describe 'Put a backslash ("\") in front of the first "!" for patterns that begin with a literal "!"' do
        # for example, "\!important!.txt".'

        before { create_file_list '!important!.txt', 'important!.txt' }

        it 'matches files starting with a literal ! if its preceded by a backslash' do
          gitignore <<~GITIGNORE
            \\!important!.txt
          GITIGNORE

          expect(subject).to allow('important!.txt').and(disallow('!important!.txt'))
        end
      end
    end

    describe 'If the pattern does not contain a slash /, Git treats it as a shell glob pattern' do
      describe 'and checks for a match against the pathname relative to the location of the .gitignore file' do
        describe '(relative to the toplevel of the work tree if not from a .gitignore file)' do
          pending "I can't understand this documentation, so i need to read the source and figure out what it means"
        end
      end
    end

    describe 'Otherwise, Git treats the pattern as a shell glob' do
      describe '"*" matches anything except "/"' do
        before { create_file_list 'f/our', 'few', 'four', 'fewer', 'favour' }

        it "matches any number of characters at the beginning if there's a star" do
          gitignore <<~GITIGNORE
            *our
          GITIGNORE

          expect(subject).to allow('few', 'fewer').and(disallow('f/our', 'four', 'favour'))
        end

        it "doesn't match a slash" do
          gitignore <<~GITIGNORE
            f*our
          GITIGNORE

          expect(subject).to allow('few', 'fewer', 'f/our').and(disallow('four', 'favour'))
        end

        it "matches any number of characters in the middle if there's a star" do
          gitignore <<~GITIGNORE
            f*r
          GITIGNORE

          expect(subject).to allow('f/our', 'few').and(disallow('four', 'fewer', 'favour'))
        end

        it "matches any number of characters at the end if there's a star" do
          gitignore <<~GITIGNORE
            few*
          GITIGNORE

          expect(subject).to allow('f/our', 'four', 'favour').and(disallow('few', 'fewer'))
        end
      end

      describe '"?" matches any one character except "/"' do
        before { create_file_list 'four', 'fouled', 'fear', 'tour', 'flour', 'favour', 'fa/our', 'foul' }

        it "matches any number of characters at the beginning if there's a star" do
          gitignore <<~GITIGNORE
            ?our
          GITIGNORE

          expect(subject).to allow('fouled', 'fear', 'favour', 'fa/our', 'foul').and(disallow('tour', 'four'))
        end

        it "doesn't match a slash" do
          gitignore <<~GITIGNORE
            fa?our
          GITIGNORE

          expect(subject).to allow('fouled', 'fear', 'tour', 'four', 'fa/our', 'foul').and(disallow('favour'))
        end

        it "matches any number of characters in the middle if there's a star" do
          gitignore <<~GITIGNORE
            f??r
          GITIGNORE

          expect(subject).to allow('fouled', 'tour', 'favour', 'fa/our', 'foul').and(disallow('four', 'fear'))
        end

        it "matches a single number of characters at the end if there's a ?" do
          gitignore <<~GITIGNORE
            fou?
          GITIGNORE

          expect(subject).to allow('fouled', 'fear', 'tour', 'favour', 'fa/our').and(disallow('foul', 'four'))
        end
      end

      describe '"[]" matches one character in a selected range' do
        before { create_file_list 'aa', 'ab', 'ac', 'bib', 'b/b' }

        it 'matches a single character in a character class' do
          gitignore <<~GITIGNORE
            a[ab]
          GITIGNORE

          expect(subject).to allow('ac').and(disallow('ab', 'aa'))
        end

        it "doesn't matches a slash even if you specify it" do
          gitignore <<~GITIGNORE
            b[i/]b
          GITIGNORE

          expect(subject).to allow('b/b').and(disallow('bib'))
        end
      end

      # See fnmatch(3) and the FNM_PATHNAME flag for a more detailed description
    end

    describe 'A leading slash matches the beginning of the pathname.' do
      # For example, "/*.c" matches "cat-file.c" but not "mozilla-sha1/sha1.c".
      before { create_file_list 'cat-file.c', 'mozilla-sha1/sha1.c' }

      it 'matches only at the beginning of everything' do
        gitignore <<~GITIGNORE
          /*.c
        GITIGNORE

        expect(subject).to allow('mozilla-sha1/sha1.c').and(disallow('cat-file.c'))
      end
    end

    describe 'Two consecutive asterisks ("**") in patterns matched against full pathname may have special meaning:' do
      describe 'A leading "**" followed by a slash means match in all directories.' do
        # 'For example, "**/foo" matches file or directory "foo" anywhere, the same as pattern "foo".
        # "**/foo/bar" matches file or directory "bar" anywhere that is directly under directory "foo".'
        before { create_file_list 'foo', 'bar/foo', 'bar/bar/bar', 'bar/bar/foo/in_dir' }

        it 'matches files or directories in all directories' do
          gitignore <<~GITIGNORE
            **/foo
          GITIGNORE

          expect(subject).to allow('bar/bar/bar').and(disallow('foo', 'bar/foo', 'bar/bar/foo/in_dir'))
        end
      end

      describe 'A trailing "/**" matches everything inside relative to the location of the .gitignore file.' do
        # For example, "abc/**" matches all files inside directory "abc",
        before { create_file_list 'abc/bar', 'abc/foo/bar', 'bar/abc/foo', 'bar/bar/foo' }

        it 'matches files or directories inside the mentioned directory' do
          gitignore <<~GITIGNORE
            abc/**
          GITIGNORE

          expect(subject).to allow('bar/bar/foo', 'bar/abc/foo').and(disallow('abc/bar', 'abc/foo/bar'))
        end

        context 'when the gitignore root is down a level from the pwd' do
          let(:args) { { gitignore: File.join(Dir.pwd, 'bar', '.gitignore') } }

          it 'matches files relative to the gitignore' do
            create_file 'bar/.gitignore', <<~GITIGNORE
              abc/**
            GITIGNORE

            expect(subject).to allow('bar/bar/foo', 'abc/bar', 'abc/foo/bar').and(disallow('bar/abc/foo'))
          end
        end
      end

      describe 'A slash followed by two consecutive asterisks then a slash matches zero or more directories.' do
        # For example, "a/**/b" matches "a/b", "a/x/b", "a/x/y/b" and so on.'
        before { create_file_list 'a/b', 'a/x/b', 'a/x/y/b', 'z/a/b', 'z/a/x/b', 'z/y' }

        it do
          gitignore <<~GITIGNORE
            a/**/b
          GITIGNORE

          expect(subject).to allow('z/y', 'z/a/b', 'z/a/x/b').and(disallow('a/b', 'a/x/b', 'a/x/y/b'))
        end
      end

      describe 'Other consecutive asterisks are considered regular asterisks' do
        describe 'and will match according to the previous rules' do
          context 'with two stars' do
            before { create_file_list 'f/our', 'few', 'four', 'fewer', 'favour' }

            it 'matches any number of characters at the beginning' do
              gitignore <<~GITIGNORE
                **our
              GITIGNORE

              expect(subject).to allow('few', 'fewer').and(disallow('f/our', 'four', 'favour'))
            end

            it "doesn't match a slash" do
              gitignore <<~GITIGNORE
                f**our
              GITIGNORE

              expect(subject).to allow('few', 'fewer', 'f/our').and(disallow('four', 'favour'))
            end

            it 'matches any number of characters in the middle' do
              gitignore <<~GITIGNORE
                f**r
              GITIGNORE

              expect(subject).to allow('f/our', 'few').and(disallow('four', 'fewer', 'favour'))
            end

            it 'matches any number of characters at the end' do
              gitignore <<~GITIGNORE
                few**
              GITIGNORE

              expect(subject).to allow('f/our', 'four', 'favour').and(disallow('few', 'fewer'))
            end
          end
        end
      end
    end
  end

  describe 'FastIgnore' do
    subject { described_class.new(relative: true, **args) }

    let(:args) { {} }

    around { |e| within_temp_dir { e.run } }

    it 'returns all files when there is no gitignore' do
      create_file_list 'foo', 'bar'
      expect(subject).to allow_exactly('foo', 'bar')
    end

    context 'when gitignore: false' do
      let(:args) { { gitignore: false } }

      it 'returns all files when there is no gitignore' do
        create_file_list 'foo', 'bar'
        expect(subject).to allow_exactly('foo', 'bar')
      end

      it 'ignores the given gitignore file and returns all files anyway' do # rubocop:disable RSpec/ExampleLength
        create_file_list 'foo', 'bar'

        gitignore <<~GITIGNORE
          foo
          bar
        GITIGNORE

        expect(subject).to allow('foo', 'bar')
      end
    end

    context 'when gitignore: true' do
      let(:args) { { gitignore: true } }

      it 'raises Errno:ENOENT when there is no gitignore' do
        expect { subject.to_a }.to raise_error(Errno::ENOENT)
      end

      it 'respects the .gitignore file when it is there' do
        create_file_list 'foo', 'bar'

        gitignore <<~GITIGNORE
          foo
        GITIGNORE

        expect(subject).to allow('bar')
      end
    end

    it 'returns hidden files' do
      create_file_list '.gitignore', '.a', '.b/.c'

      expect(subject).to allow_exactly('.gitignore', '.a', '.b/.c')
    end

    it 'ignores .git by default' do
      create_file_list '.gitignore', '.git/WHATEVER'

      expect(subject).to disallow('.git/WHATEVER')
    end

    it 'acts as though the soft links to nowhere are not there' do
      create_file_list 'foo_target', '.gitignore'
      FileUtils.ln_s('foo_target', 'foo')
      FileUtils.rm('foo_target')

      expect(subject).to disallow('foo').and(allow('.gitignore'))
    end

    it 'follows soft links' do
      create_file_list 'foo_target', '.gitignore'
      FileUtils.ln_s('foo_target', 'foo')

      expect(subject).to allow_exactly('foo', 'foo_target', '.gitignore')
    end

    it 'follows soft links to directories' do # rubocop:disable RSpec/ExampleLength
      create_file_list 'foo_target/foo_target', '.gitignore'
      gitignore <<~GITIGNORE
        foo_target
      GITIGNORE

      FileUtils.ln_s('foo_target/foo_target', 'foo')
      expect(subject).to allow_exactly('foo', '.gitignore')
    end

    it_behaves_like 'the gitignore documentation:'

    context 'when given a file other than gitignore' do
      let(:args) { { gitignore: false, ignore_files: File.join(Dir.pwd, 'fancyignore') } }

      it 'reads the non-gitignore file' do # rubocop:disable RSpec/ExampleLength
        create_file_list 'foo', 'bar', 'baz'

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        create_file 'fancyignore', <<~FANCYIGNORE
          foo
        FANCYIGNORE

        expect(subject).to disallow('foo').and(allow('bar', 'baz'))
      end
    end

    context 'when given a file including gitignore' do
      let(:args) { { ignore_files: File.join(Dir.pwd, 'fancyignore') } }

      it 'reads the non-gitignore file and the gitignore file' do # rubocop:disable RSpec/ExampleLength
        create_file_list 'foo', 'bar', 'baz'

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        create_file 'fancyignore', <<~FANCYIGNORE
          foo
        FANCYIGNORE

        expect(subject).to disallow('foo', 'bar').and(allow('baz'))
      end
    end

    context 'when given an array of ignore_rules' do
      let(:args) { { gitignore: false, ignore_rules: 'foo' } }

      it 'reads the list of rules' do
        create_file_list 'foo', 'bar', 'baz'

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        expect(subject).to disallow('foo').and(allow('bar', 'baz'))
      end
    end

    context 'when given an array of ignore_rules and gitignore' do
      let(:args) { { ignore_rules: 'foo' } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo', 'bar', 'baz'

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        expect(subject).to disallow('foo', 'bar').and(allow('baz'))
      end
    end

    context 'when given an array of include_rules and gitignore' do
      let(:args) { { include_rules: ['bar', 'baz'] } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo', 'bar', 'baz'

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        expect(subject).to disallow('foo', 'bar').and(allow('baz'))
      end
    end

    context 'when given an array of include_rules as symbols and gitignore' do
      let(:args) { { include_rules: [:bar, :baz] } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo', 'bar', 'baz'

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        expect(subject).to disallow('foo', 'bar').and(allow('baz'))
      end
    end

    context 'when given a small array of include_rules and gitignore' do
      let(:args) { { include_rules: ['bar'] } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo/bar', 'baz/bar'

        gitignore <<~GITIGNORE
          foo
        GITIGNORE

        expect(subject).to disallow('foo/bar').and(allow('baz/bar'))
      end
    end

    context 'when given an array of include_rules beginning with `/` and gitignore' do
      let(:args) { { include_rules: ['/bar', '/baz'] } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo/bar/foo', 'foo/bar/baz', 'bar/foo', 'baz'

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        expect(subject).to disallow('foo/bar/foo', 'foo/bar/baz', 'bar/foo').and(allow('baz'))
      end
    end

    context 'when given an array of include_rules ending with `/` and gitignore' do
      let(:args) { { include_rules: ['bar/', 'baz/'] } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo/baz/foo', 'foo/bar/baz', 'bar/foo', 'baz'

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        expect(subject).to disallow('baz', 'foo/bar/baz', 'bar/foo').and(allow('foo/baz/foo'))
      end
    end

    context 'when given an array of include_rules with `!` and gitignore' do
      let(:args) { { include_rules: ['fo*', '!foo', 'food'] } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo', 'food', 'foe', 'for'

        gitignore <<~GITIGNORE
          for
        GITIGNORE

        expect(subject).to disallow('foo', 'for').and(allow('foe', 'food'))
      end
    end

    context 'when given an array of argv_rules with absolute paths and gitignore' do
      let(:args) { { argv_rules: ['./bar', "#{Dir.pwd}/baz"] } }

      it 'resolves the paths to the current directory' do
        create_file_list 'foo', 'bar', 'baz'

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        expect(subject).to disallow('foo', 'bar').and(allow('baz'))
      end
    end

    context 'when given an array of negated argv_rules with absolute paths and gitignore' do
      let(:args) { { argv_rules: ['*', '!./foo', "!#{Dir.pwd}/baz"] } }

      it 'resolves the paths even when negated' do
        create_file_list 'foo', 'bar', 'baz', 'boo'

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        expect(subject).to disallow('foo', 'baz', 'bar').and(allow('boo'))
      end
    end

    context 'when given an array of unanchored argv_rules' do
      let(:args) { { argv_rules: ['**/foo', '*baz'] } }

      it 'treats the rules as unanchored' do
        create_file_list 'bar/foo', 'bar/baz', 'bar/bar', 'foo', 'baz/foo', 'baz/baz'

        expect(subject).to disallow('bar/bar', 'baz', 'bar')
          .and(allow('bar/foo', 'bar/baz', 'foo', 'baz/foo', 'baz/baz'))
      end
    end

    context 'when given an array of anchored argv_rules with absolute paths and gitignore' do
      let(:args) { { argv_rules: ['foo', 'baz'] } }

      it 'anchors the rules to the given dir, for performance reasons' do
        create_file_list 'bar/foo', 'bar/baz', 'foo', 'baz/foo', 'baz/baz'

        expect(subject).to disallow('bar/foo', 'bar/baz').and(allow('foo', 'baz/foo', 'baz/baz'))
      end
    end

    context 'when given an array of argv_rules and include_rules' do
      let(:args) { { argv_rules: ['foo', 'baz'], include_rules: ['foo', 'bar'] } }

      it 'adds the rulesets, they must pass both lists' do
        create_file_list 'foo', 'bar', 'baz'

        expect(subject).to disallow('baz', 'bar').and(allow('foo'))
      end

      it 'returns an enumerator' do
        expect(subject.each).to be_a Enumerator
        expect(subject).to respond_to :first
      end
    end

    context 'when given relative: false' do
      let(:args) { { relative: false } }

      it 'returns full paths' do
        create_file_list 'foo', 'bar', 'baz'

        expect(subject).to allow(::File.join(Dir.pwd, 'foo'), ::File.join(Dir.pwd, 'bar'), ::File.join(Dir.pwd, 'baz'))
      end
    end

    context 'when given include_shebangs and include_rules' do
      let(:args) { { include_shebangs: [:ruby], include_rules: ['*.rb', 'Rakefile'] } }

      it 'returns matching files' do # rubocop:disable RSpec/ExampleLength
        create_file 'foo', <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file 'ignored_foo', <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file 'bar', <<~BASH
          #!/usr/bin/env bash

          echo -e "no"
        BASH

        create_file 'Rakefile', <<~RUBY
          puts "ok"
        RUBY

        create_file_list 'baz', 'baz.rb'

        gitignore <<~GITIGNORE
          ignored_foo
        GITIGNORE

        expect(subject).to allow('foo', 'baz.rb', 'Rakefile').and(disallow('ignored_foo', 'bar', 'baz'))
      end
    end

    context 'when given only include_shebangs' do
      let(:args) { { include_shebangs: [:ruby] } }

      it 'returns matching files' do # rubocop:disable RSpec/ExampleLength
        create_file 'foo', <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file 'ignored_foo', <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file 'bar', <<~BASH
          #!/usr/bin/env bash

          echo -e "no"
        BASH

        create_file_list 'baz', 'baz.rb'

        gitignore <<~GITIGNORE
          ignored_foo
        GITIGNORE

        expect(subject).to allow('foo').and(disallow('ignored_foo', 'bar', 'baz', 'baz.rb'))
      end
    end

    context 'when given only include_shebangs as a single value' do
      let(:args) { { include_shebangs: :ruby } }

      it 'returns matching files' do # rubocop:disable RSpec/ExampleLength
        create_file 'foo', <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file 'ignored_foo', <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file 'bar', <<~BASH
          #!/usr/bin/env bash

          echo -e "no"
        BASH

        create_file_list 'baz', 'baz.rb'

        gitignore <<~GITIGNORE
          ignored_foo
        GITIGNORE

        expect(subject).to allow('foo').and(disallow('ignored_foo', 'bar', 'baz', 'baz.rb'))
      end
    end

    context 'when given only include_shebangs as a string list' do
      let(:args) { { include_shebangs: "ruby\nbash" } }

      it 'returns matching files' do # rubocop:disable RSpec/ExampleLength
        create_file 'foo', <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file 'ignored_foo', <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file 'bar', <<~BASH
          #!/usr/bin/env bash

          echo -e "no"
        BASH

        create_file_list 'baz', 'baz.rb'

        gitignore <<~GITIGNORE
          ignored_foo
        GITIGNORE

        expect(subject).to allow('foo', 'bar').and(disallow('ignored_foo', 'baz', 'baz.rb'))
      end
    end
  end

  describe 'git ls-files' do
    # this is included to prove the same behaviour across tools

    subject do
      `git init && git add -N .`
      `git ls-files`.split("\n")
    end

    around { |e| within_temp_dir { e.run } }

    it 'ignore .git by default' do
      create_file_list '.gitignore', '.git/WHATEVER'

      expect(subject).to disallow('.git')
    end

    it_behaves_like 'the gitignore documentation:'
  end
end
