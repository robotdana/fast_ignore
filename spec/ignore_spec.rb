# frozen_string_literal: true

RSpec.describe FastIgnore do
  around { |e| within_temp_dir { e.run } }

  let(:root) { Dir.pwd }

  shared_examples 'the gitignore documentation' do
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
          let(:ignore_rules) { '' } # just some shared behaviour shenanigans
          let(:args) { { gitignore: false, ignore_files: File.join(root, 'bar', '.gitignore') } }

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

  shared_examples 'common behaviour' do
    it 'ignore .git by default' do
      create_file_list '.gitignore', '.git/WHATEVER', 'WHATEVER'

      expect(subject).to disallow('.git/WHATEVER').and(allow('WHATEVER'))
    end
  end

  describe 'FastIgnore' do
    subject { described_class.new(relative: true, **args) }

    let(:args) { {} }
    let(:gitignore_path) { File.join(root, '.gitignore') }

    it_behaves_like 'the gitignore documentation'
    it_behaves_like 'common behaviour'

    describe 'ignore_files:' do
      subject do
        described_class.new(
          relative: true,
          gitignore: false,
          ignore_files: ignore_files,
          **args
        )
      end

      describe 'with string argument' do
        let(:ignore_files) { gitignore_path }

        it_behaves_like 'the gitignore documentation'
        it_behaves_like 'common behaviour'
      end

      describe 'with array argument' do
        let(:ignore_files) { [gitignore_path, gitignore_path] }

        it_behaves_like 'the gitignore documentation'
        it_behaves_like 'common behaviour'
      end
    end

    describe 'with a root set' do
      subject do
        Dir.chdir File.join(root, '..')
        described_class.new(relative: true, root: root, **args)
      end

      around do |example|
        Dir.mkdir 'sublevel'
        Dir.chdir 'sublevel' do
          example.run
        end
      end

      let(:root) { Dir.pwd }

      it_behaves_like 'the gitignore documentation'
      it_behaves_like 'common behaviour'
    end

    describe 'ignore_rules:' do
      subject do
        described_class.new(
          relative: true,
          gitignore: false,
          ignore_rules: ignore_rules,
          **args
        )
      end

      let(:gitignore_read) { File.exist?(gitignore_path) ? File.read(gitignore_path) : '' }

      describe 'with string argument' do
        let(:ignore_rules) { gitignore_read }

        it_behaves_like 'the gitignore documentation'
        it_behaves_like 'common behaviour'
      end

      describe 'with array argument' do
        let(:ignore_rules) { gitignore_read.each_line.to_a }

        it_behaves_like 'the gitignore documentation'
        it_behaves_like 'common behaviour'
      end
    end
  end

  describe 'git ls-files' do
    subject do
      `git init && git add -N .`
      `git ls-files`.split("\n")
    end

    it_behaves_like 'the gitignore documentation'
    it_behaves_like 'common behaviour'
  end
end
