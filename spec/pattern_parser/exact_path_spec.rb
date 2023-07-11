# frozen_string_literal: true

RSpec.describe PathList::PatternParser::ExactPath do
  subject(:matcher) { described_class.new(path, polarity, nil).matcher }

  let(:case_insensitive) { false }
  let(:path) { "#{FSROOT}path/to/exact/something" }
  let(:candidate_path) { path }
  let(:candidate) { PathList::Candidate.new(candidate_path, true) }
  let(:polarity) { :allow }

  before do
    allow(PathList::CanonicalPath).to receive(:case_insensitive?).and_return(case_insensitive)
  end

  describe '#implicit_matcher' do
    subject(:matcher) { described_class.new(path, polarity, nil).implicit_matcher }

    it 'builds a regex that matches parent and child somethings' do
      expect(matcher).to be_like(
        PathList::Matcher::Any::Two.new([
          PathList::Matcher::MatchIfDir.new(
            PathList::Matcher::ExactString::Set.new(
              [FSROOT, "#{FSROOT}path", "#{FSROOT}path/to", "#{FSROOT}path/to/exact"], :allow
            )
          ),
          PathList::Matcher::PathRegexp.new(%r{\A#{FSROOT}path/to/exact/something/}o, :allow)
        ])
      )
    end

    it 'builds a regex that matches parent and child somethings when case insensitive' do
      allow(PathList::CanonicalPath).to receive(:case_insensitive?).and_return(true)

      expect(matcher).to be_like(
        PathList::Matcher::Any::Two.new([
          PathList::Matcher::MatchIfDir.new(
            PathList::Matcher::ExactString::Set::CaseInsensitive.new(
              [
                FSROOT_LOWER, "#{FSROOT_LOWER}path", "#{FSROOT_LOWER}path/to",
                "#{FSROOT_LOWER}path/to/exact"
              ], :allow
            )
          ),
          PathList::Matcher::PathRegexp::CaseInsensitive.new(%r{\A#{FSROOT_LOWER}path/to/exact/something/}o, :allow)
        ])
      )
    end

    describe 'with root and relative path' do
      subject(:matcher) { described_class.new('./exact/something', polarity, "#{FSROOT}path/to").implicit_matcher }

      it 'builds a regex that matches parent and child somethings' do
        expect(matcher).to be_like(
          PathList::Matcher::Any::Two.new([
            PathList::Matcher::MatchIfDir.new(
              PathList::Matcher::ExactString::Set.new(
                [FSROOT, "#{FSROOT}path", "#{FSROOT}path/to", "#{FSROOT}path/to/exact"], :allow
              )
            ),
            PathList::Matcher::PathRegexp.new(%r{\A#{FSROOT}path/to/exact/something/}o, :allow)
          ])
        )
      end

      it 'builds a regex that matches parent and child somethings when case insensitive' do
        allow(PathList::CanonicalPath).to receive(:case_insensitive?).and_return(true)

        expect(matcher).to be_like(
          PathList::Matcher::Any::Two.new([
            PathList::Matcher::MatchIfDir.new(
              PathList::Matcher::ExactString::Set::CaseInsensitive.new(
                [
                  FSROOT_LOWER, "#{FSROOT_LOWER}path", "#{FSROOT_LOWER}path/to",
                  "#{FSROOT_LOWER}path/to/exact"
                ], :allow
              )
            ),
            PathList::Matcher::PathRegexp::CaseInsensitive.new(%r{\A#{FSROOT_LOWER}path/to/exact/something/}o, :allow)
          ])
        )
      end
    end

    it "doesn't need to match exact path" do
      expect(matcher.match(PathList::Candidate.new(path, true))).to be_nil
    end

    it 'matches most parent path' do
      expect(matcher.match(PathList::Candidate.new("#{FSROOT}path", true)))
        .to be :allow
    end

    it 'matches exact case' do
      expect(matcher.match(PathList::Candidate.new("#{FSROOT}PATH", true))).to be_nil
    end

    context 'when case insensitive' do
      let(:case_insensitive) { true }

      it 'matches most parent path regardless of case' do
        expect(matcher.match(PathList::Candidate.new("#{FSROOT}PATH", true))).to be :allow
      end
    end

    it 'matches parent path' do
      expect(matcher.match(PathList::Candidate.new("#{FSROOT}path/to", true)))
        .to be :allow
    end

    it 'matches child path' do
      expect(matcher.match(PathList::Candidate.new("#{path}/child", true)))
        .to be :allow
    end

    it 'matches grandchild path' do
      expect(matcher.match(PathList::Candidate.new("#{path}/child/child", true)))
        .to be :allow
    end

    it "doesn't match path starting with the same string" do
      expect(matcher.match(PathList::Candidate.new("#{path}_part_2", true)))
        .to be_nil
    end

    it "doesn't match parent path starting with the same string" do
      expect(matcher.match(PathList::Candidate.new("#{FSROOT}path/to/exact-ish/something", true)))
        .to be_nil
    end

    it "doesn't match path sibling" do
      expect(matcher.match(PathList::Candidate.new("#{FSROOT}path/to/exact/other", true)))
        .to be_nil
    end

    it "doesn't match path concatenation" do
      expect(matcher.match(PathList::Candidate.new("#{FSROOT}pathtoexactsomething", true))) # spellr:disable-line
        .to be_nil
    end
  end

  describe '#matcher' do
    subject(:matcher) { described_class.new(path, polarity, nil).matcher }

    let(:polarity) { :ignore }

    it 'builds a matcher that matches exact something' do
      expect(matcher).to be_like(
        PathList::Matcher::ExactString.new("#{FSROOT}path/to/exact/something", :ignore)
      )
    end

    it 'matches exact path' do
      expect(matcher.match(PathList::Candidate.new(path, true))).to be :ignore
    end

    it 'matches exact case' do
      expect(matcher.match(PathList::Candidate.new(path.upcase, true))).to be_nil
    end

    context 'when case insensitive' do
      let(:case_insensitive) { true }

      it 'matches most parent path regardless of case' do
        expect(matcher.match(PathList::Candidate.new(path.upcase, true))).to be :ignore
      end
    end

    it "doesn't match most parent path" do
      expect(matcher.match(PathList::Candidate.new("#{FSROOT}path", true)))
        .to be_nil
    end

    it "doesn't match parent path" do
      expect(matcher.match(PathList::Candidate.new("#{FSROOT}path/to", true)))
        .to be_nil
    end

    it "doesn't match child path" do
      expect(matcher.match(PathList::Candidate.new("#{path}/child", true)))
        .to be_nil
    end
  end
end
