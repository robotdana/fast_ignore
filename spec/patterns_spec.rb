# frozen_string_literal: true

RSpec.describe PathList::Patterns do
  subject(:matchers) do
    described_class.build(
      patterns_arg,
      from_file: from_file,
      format: format_arg,
      root: root,
      allow: allow_arg
    ).build
  end

  let(:patterns) { [] }
  let(:patterns_arg) { from_file ? [] : Array(patterns) }
  let(:from_file) { nil }
  let(:format_arg) { nil }
  let(:root) { nil }
  let(:allow_arg) { false }

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
      let(:allow_arg) { false }

      it 'matches everything' do
        expect(matchers).to be_like PathList::Matchers::Allow
      end
    end

    context 'when allow' do
      let(:allow_arg) { true }

      it 'matches everything' do
        expect(matchers).to be_like PathList::Matchers::Allow
      end
    end
  end

  describe 'with some patterns' do
    let(:patterns) { 'a' }
    let(:root) { '/' }

    context 'when ignore' do
      let(:allow_arg) { false }

      it 'ignores a' do
        expect(matchers).to be_like PathList::Matchers::LastMatch::Two.new(
          PathList::Matchers::Allow,
          PathList::Matchers::PathRegexp.new(%r{/a\z}i, false)
        )
      end
    end

    context 'when allow' do
      let(:allow_arg) { true }

      it 'allows a, and implicitly any parents and children of a' do
        expect(matchers).to be_like PathList::Matchers::LastMatch.new([
          PathList::Matchers::Ignore,
          PathList::Matchers::PathRegexp.new(%r{/a(?:/|\z)}i, true),
          PathList::Matchers::AllowAnyDir
        ])
      end
    end

    context 'with a root' do
      let(:root) { '/b' }

      context 'when ignore' do
        let(:allow_arg) { false }

        it 'ignores a' do
          expect(matchers).to be_like PathList::Matchers::LastMatch::Two.new(
            PathList::Matchers::Allow,
            PathList::Matchers::PathRegexp.new(%r{\A/b/(?:.*/)?a\z}i, false)
          )
        end
      end

      context 'when allow' do
        let(:allow_arg) { true }

        it 'allows a, and implicitly any children of a' do
          expect(matchers).to be_like PathList::Matchers::LastMatch.new([
            PathList::Matchers::Ignore,
            PathList::Matchers::PathRegexp.new(%r{\A/b/(?:.*/)?a(?:/|\z)}i, true),
            PathList::Matchers::MatchIfDir.new(
              PathList::Matchers::PathRegexp.new(%r{\A/(?:\z|b(?:\z|/))}i, true)
            )
          ])
        end
      end
    end

    # f38b597

    describe 'with glob format' do
      let(:patterns) { ['*', '!./foo', '!/a/b/c/baz'] }
      let(:root) { '/a/b/c' }
      let(:format_arg) { :glob }

      context 'when ignore' do
        let(:allow_arg) { false }

        it 'builds correct matchers (correctness verified by other tests, i just want visibility)' do
          expect(matchers).to be_like PathList::Matchers::LastMatch.new([
            PathList::Matchers::Allow,
            PathList::Matchers::PathRegexp.new(%r{\A/a/b/c/}i, false),
            PathList::Matchers::PathRegexp.new(%r{\A/a/b/c/(?:foo\z|baz\z)}i, true)
          ])
        end
      end

      context 'when allow' do
        let(:allow_arg) { true }

        it 'builds correct matchers (correctness verified by other tests, i just want visibility)' do
          expect(matchers).to be_like PathList::Matchers::LastMatch.new([
            PathList::Matchers::Ignore,
            PathList::Matchers::PathRegexp.new(%r{\A/a/b/c/(?:|.*/)}i, true),
            PathList::Matchers::MatchIfDir.new(
              PathList::Matchers::PathRegexp.new(%r{\A/(?:\z|a(?:\z|/b(?:\z|/c\z)))}i, true)
            ),
            PathList::Matchers::PathRegexp.new(%r{\A/a/b/c/(?:foo\z|baz\z)}i, false)
          ])
        end
      end
    end

    describe 'with more complex patterns' do
      let(:patterns) { ['a', '/b', 'd', '/bb', '!c/d', '**/e', '# comment'] }
      let(:root) { '/f/g/' }

      context 'when ignore' do
        let(:allow_arg) { false }

        it 'builds correct matchers (correctness verified by other tests, i just want visibility)' do
          expect(matchers).to be_like PathList::Matchers::LastMatch.new([
            PathList::Matchers::Allow,
            PathList::Matchers::PathRegexp.new(%r{\A/f/g/(?:b\z|bb\z|(?:.*/)?(?:a\z|d\z))}i, false),
            PathList::Matchers::PathRegexp.new(%r{\A/f/g/c/d\z}i, true),
            PathList::Matchers::PathRegexp.new(%r{\A/f/g/(?:.*/)?e\z}i, false)
          ])
        end
      end

      context 'when allow' do
        let(:allow_arg) { true }

        it 'builds correct matchers (correctness verified by other tests, i just want visibility)' do
          expect(matchers).to be_like PathList::Matchers::LastMatch.new([
            PathList::Matchers::Ignore,
            PathList::Matchers::PathRegexp.new(
              %r{\A/f/g/(?:b(?:\z|/)|bb(?:\z|/)|(?:.*/)?(?:a(?:\z|/)|d(?:\z|/)|e/))}i, true
            ),
            PathList::Matchers::MatchIfDir.new(
              PathList::Matchers::PathRegexp.new(%r{\A/(?:\z|f(?:\z|/g(?:\z|/)))}i, true)
            ),
            PathList::Matchers::PathRegexp.new(%r{\A/f/g/c/d\z}i, false),
            PathList::Matchers::PathRegexp.new(%r{\A/f/g/(?:.*/)?e\z}i, true)
          ])
        end
      end
    end
  end
end
