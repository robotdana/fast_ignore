# frozen_string_literal: true

require 'pathname'
RSpec::Matchers.define_negated_matcher(:exclude, :include)
RSpec.describe FindIgnore do
  it 'has a version number' do
    expect(FindIgnore::VERSION).not_to be nil
  end

  describe '#files' do
    subject { described_class.new.files.map { |e| e.delete_prefix("#{Dir.pwd}/") } }

    around { |e| within_temp_dir { e.run } }

    it 'returns all files when there is no gitignore' do
      create_file_list 'foo', 'bar'
      expect(subject).to include('foo', 'bar')
    end

    shared_examples 'gitignore' do
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
        describe 'any matching file excluded by a previous pattern will become included again' do
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

          before { create_file_list '!important!.txt' }

          it 'matches files starting with a literal ! if its preceeded by a backslash' do
            gitignore <<~GITIGNORE
              \!important!.txt
            GITIGNORE

            expect(subject).to include
          end
        end
      end

      describe 'If the pattern does not contain a slash /, Git treats it as a shell glob pattern' do
        # and checks for a match against the pathname relative to the location of the .gitignore file
        # (relative to the toplevel of the work tree if not from a .gitignore file)'

        before { create_file_list 'a/c', 'a/b/c', 'a/d' }

        it "matches * against slashes if the pattern doesn't contain a slash" do
          pending "These don't seem to work as described in git, so i'll not try to make it work for this gem"
          gitignore <<~GITIGNORE
            a*c
          GITIGNORE
          expect(subject).to exclude('a/c', 'a/b/c').and(include('a/d'))
        end

        it "matches ? against slashes if the pattern doesn't contain a slash" do
          pending "These don't seem to work as described in git, so i'll not try to make it work for this gem"
          gitignore <<~GITIGNORE
            a?c
          GITIGNORE
          expect(subject).to exclude('a/c').and(include('a/b/c', 'a/d'))
        end
      end

      describe 'Otherwise, Git treats the pattern as a shell glob' do
        describe '"*" matches anything except "/"' do
          before { create_file_list 'our', 'few', 'four', 'fewer', 'favour' }

          it "matches any number of characters at the beginning if there's a star" do
            gitignore <<~GITIGNORE
              *our
            GITIGNORE

            expect(subject).to include('few', 'fewer').and(exclude('our', 'four', 'favour'))
          end

          it "matches any number of characters in the middle if there's a star" do
            gitignore <<~GITIGNORE
              f*r
            GITIGNORE

            expect(subject).to include('our', 'few').and(exclude('four', 'fewer', 'favour'))
          end

          it "matches any number of characters at the end if there's a star" do
            gitignore <<~GITIGNORE
              few*
            GITIGNORE

            expect(subject).to include('our', 'four', 'favour').and(exclude('few', 'fewer'))
          end
        end

        describe '"?" matches any one character except "/"'
        describe '"[]" matches one character in a selected range'

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
          pending
        end

        describe 'A trailing "/**" matches everything inside.' do
          # For example, "abc/**" matches all files inside directory "abc",
          # relative to the location of the .gitignore file, with infinite depth
          pending
        end

        describe 'A slash followed by two consecutive asterisks then a slash matches zero or more directories.' do
          # For example, "a/**/b" matches "a/b", "a/x/b", "a/x/y/b" and so on.'
          pending
        end

        describe 'Other consecutive asterisks are considered regular asterisks' do
          # and will match according to the previous rules
          pending
        end
      end
    end

    describe 'ruby version' do
      it_behaves_like 'gitignore'
    end

    describe 'git version' do
      # this is included to prove the same behaviour across tools
      subject do
        `git init && git add -N .`
        `git ls-files`.split("\n")
      end

      it_behaves_like 'gitignore'
    end
  end
end
