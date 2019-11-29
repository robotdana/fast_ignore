# frozen_string_literal: true

require 'pathname'
RSpec::Matchers.define_negated_matcher(:exclude, :include)
RSpec.describe FastIgnore do
  it 'has a version number' do
    expect(FastIgnore::VERSION).not_to be nil
  end

  shared_examples 'the gitignore documentation:' do
    describe 'A blank line matches no files, so it can serve as a separator for readability.' do
      before { create_file_list 'foo', 'bar', 'baz' }

      it 'ignores nothing when gitignore is empty' do
        gitignore ''

        expect(subject).to include('foo', 'bar', 'baz')
      end

      it 'ignores nothing when gitignore only contains newlines' do
        gitignore <<~GITIGNORE


        GITIGNORE

        expect(subject).to include('foo', 'bar', 'baz')
      end

      it 'ignores mentioned files when gitignore includes newlines' do
        gitignore <<~GITIGNORE

          foo
          bar

        GITIGNORE

        expect(subject).to include('baz').and(exclude('foo', 'bar'))
      end
    end

    describe 'A line starting with # serves as a comment.' do
      before { create_file_list '#foo', 'foo' }

      it "doesn't ignore files whose names look like a comment" do
        gitignore <<~GITIGNORE
          #foo
          foo
        GITIGNORE

        expect(subject).to include('#foo').and(exclude('foo'))
      end

      describe 'Put a backslash ("\") in front of the first hash for patterns that begin with a hash' do
        it 'ignores files whose names look like a comment when prefixed with a backslash' do
          gitignore <<~GITIGNORE
            \\#foo
          GITIGNORE

          expect(subject).to include('foo').and(exclude('#foo'))
        end
      end
    end

    describe 'Trailing spaces are ignored unless they are quoted with backslash ("\")' do
      before { create_file_list 'foo', 'foo ', 'foo  ' }

      it 'ignores trailing spaces in the gitignore file' do
        gitignore 'foo  '

        expect(subject).to include('foo  ', 'foo ').and(exclude('foo'))
      end

      it "doesn't ignore trailing spaces if there's a backslash" do
        gitignore "foo \\ \n"

        expect(subject).to include('foo', 'foo ').and(exclude('foo  '))
      end

      it "doesn't ignore trailing spaces if there's a backslash before every space" do
        gitignore "foo\\ \\ \n"

        expect(subject).to include('foo', 'foo ').and(exclude('foo  '))
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

          expect(subject).to include('bar/foo').and(exclude('foo/bar'))
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

          expect(subject).to include('foo').and(exclude('foe'))
        end

        it 'is read in order' do
          gitignore <<~GITIGNORE
            !foo
            fo*
          GITIGNORE

          expect(subject).to exclude('foe', 'foo')
        end

        it 'has no effect if not negating anything' do
          gitignore <<~GITIGNORE
            !foo
          GITIGNORE
          expect(subject).to include('foe', 'foo')
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

          expect(subject).to include('bar/bar').and(exclude('foo/bar', 'foo/foo'))
        end
      end

      describe 'Put a backslash ("\") in front of the first "!" for patterns that begin with a literal "!"' do
        # for example, "\!important!.txt".'

        before { create_file_list '!important!.txt', 'important!.txt' }

        it 'matches files starting with a literal ! if its preceeded by a backslash' do
          gitignore <<~GITIGNORE
            \\!important!.txt
          GITIGNORE

          expect(subject).to include('important!.txt').and(exclude('!important!.txt'))
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

          expect(subject).to include('few', 'fewer').and(exclude('f/our', 'four', 'favour'))
        end

        it "doesn't match a slash" do
          gitignore <<~GITIGNORE
            f*our
          GITIGNORE

          expect(subject).to include('few', 'fewer', 'f/our').and(exclude('four', 'favour'))
        end

        it "matches any number of characters in the middle if there's a star" do
          gitignore <<~GITIGNORE
            f*r
          GITIGNORE

          expect(subject).to include('f/our', 'few').and(exclude('four', 'fewer', 'favour'))
        end

        it "matches any number of characters at the end if there's a star" do
          gitignore <<~GITIGNORE
            few*
          GITIGNORE

          expect(subject).to include('f/our', 'four', 'favour').and(exclude('few', 'fewer'))
        end
      end

      describe '"?" matches any one character except "/"' do
        before { create_file_list 'four', 'fouled', 'fear', 'tour', 'flour', 'favour', 'fa/our', 'foul' }

        it "matches any number of characters at the beginning if there's a star" do
          gitignore <<~GITIGNORE
            ?our
          GITIGNORE

          expect(subject).to include('fouled', 'fear', 'favour', 'fa/our', 'foul').and(exclude('tour', 'four'))
        end

        it "doesn't match a slash" do
          gitignore <<~GITIGNORE
            fa?our
          GITIGNORE

          expect(subject).to include('fouled', 'fear', 'tour', 'four', 'fa/our', 'foul').and(exclude('favour'))
        end

        it "matches any number of characters in the middle if there's a star" do
          gitignore <<~GITIGNORE
            f??r
          GITIGNORE

          expect(subject).to include('fouled', 'tour', 'favour', 'fa/our', 'foul').and(exclude('four', 'fear'))
        end

        it "matches a single number of characters at the end if there's a ?" do
          gitignore <<~GITIGNORE
            fou?
          GITIGNORE

          expect(subject).to include('fouled', 'fear', 'tour', 'favour', 'fa/our').and(exclude('foul', 'four'))
        end
      end

      describe '"[]" matches one character in a selected range' do
        before { create_file_list 'aa', 'ab', 'ac', 'bib', 'b/b' }

        it 'matches a single character in a character class' do
          gitignore <<~GITIGNORE
            a[ab]
          GITIGNORE

          expect(subject).to include('ac').and(exclude('ab', 'aa'))
        end

        it "doesn't matches a slash even if you specify it" do
          gitignore <<~GITIGNORE
            b[i/]b
          GITIGNORE

          expect(subject).to include('b/b').and(exclude('bib'))
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

        expect(subject).to include('mozilla-sha1/sha1.c').and(exclude('cat-file.c'))
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

          expect(subject).to include('bar/bar/bar').and(exclude('foo', 'bar/foo', 'bar/bar/foo/in_dir'))
        end
      end

      describe 'A trailing "/**" matches everything inside relative to the location of the .gitignore file.' do
        # For example, "abc/**" matches all files inside directory "abc",
        before { create_file_list 'abc/bar', 'abc/foo/bar', 'bar/abc/foo', 'bar/bar/foo' }

        it 'matches files or directories inside the mentioned directory' do
          gitignore <<~GITIGNORE
            abc/**
          GITIGNORE

          expect(subject).to include('bar/bar/foo', 'bar/abc/foo').and(exclude('abc/bar', 'abc/foo/bar'))
        end

        context 'when the gitigore root is down a level from the pwd' do
          let(:args) { { gitignore: File.join(Dir.pwd, 'bar', '.gitignore') } }

          it 'matches files relative to the gitignore' do
            create_file 'bar/.gitignore', <<~GITIGNORE
              abc/**
            GITIGNORE

            expect(subject).to include('bar/bar/foo', 'abc/bar', 'abc/foo/bar').and(exclude('bar/abc/foo'))
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

          expect(subject).to include('z/y', 'z/a/b', 'z/a/x/b').and(exclude('a/b', 'a/x/b', 'a/x/y/b'))
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

              expect(subject).to include('few', 'fewer').and(exclude('f/our', 'four', 'favour'))
            end

            it "doesn't match a slash" do
              gitignore <<~GITIGNORE
                f**our
              GITIGNORE

              expect(subject).to include('few', 'fewer', 'f/our').and(exclude('four', 'favour'))
            end

            it 'matches any number of characters in the middle' do
              gitignore <<~GITIGNORE
                f**r
              GITIGNORE

              expect(subject).to include('f/our', 'few').and(exclude('four', 'fewer', 'favour'))
            end

            it 'matches any number of characters at the end' do
              gitignore <<~GITIGNORE
                few**
              GITIGNORE

              expect(subject).to include('f/our', 'four', 'favour').and(exclude('few', 'fewer'))
            end
          end
        end
      end
    end
  end

  describe '#to_a' do
    subject { described_class.new(relative: true, **args).to_a }

    let(:args) { {} }

    around { |e| within_temp_dir { e.run } }

    context 'without a gitignore file' do
      let(:args) { { gitignore: false } }

      it 'returns all files when there is no gitignore' do
        create_file_list 'foo', 'bar'
        expect(subject).to contain_exactly('foo', 'bar')
      end
    end

    it 'returns hidden files' do
      create_file_list '.gitignore', '.a', '.b/.c'

      expect(subject).to contain_exactly('.gitignore', '.a', '.b/.c')
    end

    it 'ignores .git by default' do
      create_file_list '.gitignore', '.git/WHATEVER'

      expect(subject).to exclude('.git/WHATEVER')
    end

    it 'acts as though the soft links to nowhere are not there' do
      create_file_list 'foo_target', '.gitignore'
      FileUtils.ln_s('foo_target', 'foo')
      FileUtils.rm('foo_target')

      expect(subject).to exclude('foo').and(include('.gitignore'))
    end

    it 'follows soft links' do
      create_file_list 'foo_target', '.gitignore'
      FileUtils.ln_s('foo_target', 'foo')
      expect(subject).to contain_exactly('foo', 'foo_target', '.gitignore')
    end

    it 'follows soft links to directories' do # rubocop:disable RSpec/ExampleLength
      create_file_list 'foo_target/foo_target', '.gitignore'
      gitignore <<~GITIGNORE
        foo_target
      GITIGNORE

      FileUtils.ln_s('foo_target/foo_target', 'foo')
      expect(subject).to contain_exactly('foo', '.gitignore')
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

        expect(subject).to exclude('foo').and(include('bar', 'baz'))
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

        expect(subject).to exclude('foo', 'bar').and(include('baz'))
      end
    end

    context 'when given an array of ignore_rules' do
      let(:args) { { gitignore: false, ignore_rules: 'foo' } }

      it 'reads the list of rules' do
        create_file_list 'foo', 'bar', 'baz'

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        expect(subject).to exclude('foo').and(include('bar', 'baz'))
      end
    end

    context 'when given an array of ignore_rules and gitignore' do
      let(:args) { { ignore_rules: 'foo' } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo', 'bar', 'baz'

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        expect(subject).to exclude('foo', 'bar').and(include('baz'))
      end
    end

    context 'when given an array of include_rules and gitignore' do
      let(:args) { { include_rules: ['bar', 'baz'] } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo', 'bar', 'baz'

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        expect(subject).to exclude('foo', 'bar').and(include('baz'))
      end
    end

    context 'when given an array of include_rules and gitignore' do
      let(:args) { { include_rules: ['bar', 'baz'] } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo', 'bar', 'baz'

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        expect(subject).to exclude('foo', 'bar').and(include('baz'))
      end
    end

    context 'when given an array of include_rules and gitignore' do
      let(:args) { { include_rules: ['bar'] } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo/bar', 'baz/bar'

        gitignore <<~GITIGNORE
          foo
        GITIGNORE

        expect(subject).to exclude('foo/bar').and(include('baz/bar'))
      end
    end

    context 'when given an array of include_rules beginnig with `/` and gitignore' do
      let(:args) { { include_rules: ['/bar', '/baz'] } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo/bar/foo', 'foo/bar/baz', 'bar/foo', 'baz'

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        expect(subject).to exclude('foo/bar/foo', 'foo/bar/baz', 'bar/foo').and(include('baz'))
      end
    end

    context 'when given an array of include_rules ending with `/` and gitignore' do
      let(:args) { { include_rules: ['bar/', 'baz/'] } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo/baz/foo', 'foo/bar/baz', 'bar/foo', 'baz'

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        expect(subject).to exclude('baz', 'foo/bar/baz', 'bar/foo').and(include('foo/baz/foo'))
      end
    end

    context 'when given an array of include_rules with `!` and gitignore' do
      let(:args) { { include_rules: ['fo*', '!foo', 'food'] } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo', 'food', 'foe', 'for'

        gitignore <<~GITIGNORE
          for
        GITIGNORE

        expect(subject).to exclude('foo', 'for').and(include('foe', 'food'))
      end
    end

    context 'when given an array of include_rules and gitignore' do
      let(:args) { { include_rules: ['./bar', "#{Dir.pwd}/baz"] } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo', 'bar', 'baz'

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        expect(subject).to exclude('foo', 'bar').and(include('baz'))
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

      expect(subject).to exclude('.git')
    end

    it_behaves_like 'the gitignore documentation:'
  end
end
