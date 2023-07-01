# frozen_string_literal: true

RSpec.describe PathList::Patterns do
  subject(:matchers) do
    described_class.build(
      patterns_arg,
      from_file: from_file,
      format: format_arg,
      root: root,
      polarity: polarity
    ).build
  end

  let(:patterns) { [] }
  let(:patterns_arg) { from_file ? [] : Array(patterns) }
  let(:from_file) { nil }
  let(:format_arg) { nil }
  let(:root) { nil }
  let(:polarity) { :ignore }

  around do |e|
    if from_file
      within_temp_dir { e.run }
    else
      e.run
    end
  end

  before do
    stub_file patterns.join("\n"), from_file if from_file
  end

  describe 'with blank patterns' do
    context 'when ignore' do
      let(:polarity) { :ignore }

      it 'matches everything' do
        expect(matchers).to be_like PathList::Matchers::Allow
      end
    end

    context 'when allow' do
      let(:polarity) { :allow }

      it 'matches everything' do
        expect(matchers).to be_like PathList::Matchers::Allow
      end
    end
  end

  context 'with patterns: "a", root: "/"' do
    let(:patterns) { 'a' }
    let(:root) { '/' }

    context 'when ignore' do
      let(:polarity) { :ignore }

      it 'ignores a' do
        expect(matchers).to be_like PathList::Matchers::LastMatch::Two.new([
          PathList::Matchers::Allow,
          PathList::Matchers::PathRegexp.new(%r{/a\z}, :ignore)
        ])
      end
    end

    context 'when allow' do
      let(:polarity) { :allow }

      it 'allows a, and implicitly any parents and children of a' do
        expect(matchers).to be_like PathList::Matchers::LastMatch.new([
          PathList::Matchers::Ignore,
          PathList::Matchers::PathRegexp.new(%r{/a(?:\z|/)}, :allow),
          PathList::Matchers::AllowAnyDir
        ])
      end
    end
  end

  context 'with patterns: "a", root: "/b"' do
    let(:patterns) { 'a' }
    let(:root) { '/b' }

    context 'when ignore' do
      let(:polarity) { :ignore }

      it 'ignores a' do
        expect(matchers).to be_like PathList::Matchers::LastMatch::Two.new([
          PathList::Matchers::Allow,
          PathList::Matchers::PathRegexp.new(%r{\A/b/(?:.*/)?a\z}, :ignore)
        ])
      end
    end

    context 'when allow' do
      let(:polarity) { :allow }

      it 'allows a, and implicitly any children of a' do
        expect(matchers).to be_like PathList::Matchers::LastMatch.new([
          PathList::Matchers::Ignore,
          PathList::Matchers::PathRegexp.new(%r{\A/b/(?:.*/)?a(?:\z|/)}, :allow),
          PathList::Matchers::MatchIfDir.new(
            PathList::Matchers::Any::Two.new([
              PathList::Matchers::ExactString::Set.new(['/', '/b'], :allow),
              PathList::Matchers::PathRegexp.new(%r{\A/b/}, :allow)
            ])
          )
        ])
      end
    end
  end

  context 'with patterns: ["a[b]", "a[^c]"], root: "/"' do
    let(:patterns) { ['a[b]', 'a[^c]'] }
    let(:root) { '/' }

    context 'when ignore' do
      let(:polarity) { :ignore }

      it "doesn't merge the character classes" do
        expect(matchers).to be_like PathList::Matchers::LastMatch::Two.new([
          PathList::Matchers::Allow,
          PathList::Matchers::PathRegexp.new(%r{/a(?:(?!/)[b]\z|(?!/)[^c]\z)}, :ignore)
        ])
      end
    end

    context 'when allow' do
      let(:polarity) { :allow }

      it "doesn't merge the character classes" do
        expect(matchers).to be_like PathList::Matchers::LastMatch.new([
          PathList::Matchers::Ignore,
          PathList::Matchers::PathRegexp.new(%r{/a(?:(?!/)[b](?:\z|/)|(?!/)[^c](?:\z|/))}, :allow),
          PathList::Matchers::AllowAnyDir
        ])
      end
    end
  end

  context 'with patterns: ["*", "!./foo", "!/a/b/c/baz"], root: "/a/b/c", format: :glob' do
    let(:patterns) { ['*', '!./foo', '!/a/b/c/baz'] }
    let(:root) { '/a/b/c' }
    let(:format_arg) { :glob }

    context 'when ignore' do
      let(:polarity) { :ignore }

      it 'builds correct matchers (correctness verified by other tests, i just want visibility)' do
        expect(matchers).to be_like PathList::Matchers::LastMatch.new([
          PathList::Matchers::Allow,
          PathList::Matchers::PathRegexp.new(%r{\A/a/b/c/}, :ignore),
          PathList::Matchers::ExactString::Set.new([
            '/a/b/c/foo',
            '/a/b/c/baz'
          ], :allow)
        ])
      end
    end

    context 'when allow' do
      let(:polarity) { :allow }

      it 'builds correct matchers (correctness verified by other tests, i just want visibility)' do
        expect(matchers).to be_like PathList::Matchers::LastMatch.new([
          PathList::Matchers::Ignore,
          PathList::Matchers::PathRegexp.new(%r{\A/a/b/c/}, :allow),
          PathList::Matchers::MatchIfDir.new(
            PathList::Matchers::Any::Two.new([
              PathList::Matchers::ExactString::Set.new(['/', '/a', '/a/b', '/a/b/c'], :allow),
              PathList::Matchers::PathRegexp.new(%r{\A/a/b/c/}, :allow)
            ])
          ),
          PathList::Matchers::ExactString::Set.new([
            '/a/b/c/foo',
            '/a/b/c/baz'
          ], :ignore)
        ])
      end
    end
  end

  context 'with patterns: ["a*", "/b*", "d*", "/bb*", "!c/d*", "**/e*", "# comment"], root: "/f/g"' do
    let(:patterns) { ['a*', '/b*', 'd*', '/bb*', '!c/d*', '**/e*', '# comment'] }
    let(:root) { '/f/g/' }

    context 'when ignore' do
      let(:polarity) { :ignore }

      it 'builds correct matchers (correctness verified by other tests, i just want visibility)' do
        expect(matchers).to be_like PathList::Matchers::LastMatch.new([
          PathList::Matchers::Allow,
          PathList::Matchers::PathRegexp.new(
            %r{\A/f/g/(?:b[^\/]*\z|bb[^\/]*\z|(?:.*/)?(?:a[^\/]*\z|d[^\/]*\z))}, :ignore
          ),
          PathList::Matchers::PathRegexp.new(%r{\A/f/g/c/d[^\/]*\z}, :allow),
          PathList::Matchers::PathRegexp.new(%r{\A/f/g/(?:.*/)?e[^\/]*\z}, :ignore)
        ])
      end
    end

    context 'when allow' do
      let(:polarity) { :allow }

      it 'builds correct matchers (correctness verified by other tests, i just want visibility)' do
        expect(matchers).to be_like PathList::Matchers::LastMatch.new([
          PathList::Matchers::Ignore,
          PathList::Matchers::PathRegexp.new(
            %r{\A/f/g/(?:b[^\/]*(?:\z|/)|bb[^\/]*(?:\z|/)|(?:.*/)?(?:a[^\/]*(?:\z|/)|d[^\/]*(?:\z|/)|e[^\/]*/))},
            :allow
          ),
          PathList::Matchers::MatchIfDir.new(
            PathList::Matchers::Any::Two.new([
              PathList::Matchers::ExactString::Set.new(['/', '/f', '/f/g'], :allow),
              PathList::Matchers::PathRegexp.new(%r{\A/f/g/}, :allow)
            ])
          ),
          PathList::Matchers::PathRegexp.new(%r{\A/f/g/c/d[^\/]*\z}, :ignore),
          PathList::Matchers::PathRegexp.new(%r{\A/f/g/(?:.*/)?e[^\/]*\z}, :allow)
        ])
      end
    end
  end
end
