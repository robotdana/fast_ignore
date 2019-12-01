#[macro_use]

extern crate helix;

mod rule;
use rule::Rule;

ruby! {
    class FastIgnoreRule {
        struct {
            rule: String,
            dir_only: bool,
            negation: bool
        }

        def initialize(helix, rule: String, dir_only: bool, negation: bool) {
            FastIgnoreRule { helix, rule, dir_only, negation }
        }

        def negation(&self) -> bool {
            self.negation
        }

        def dir_only(&self) -> bool {
            self.dir_only
        }

        def fnmatch(&self, path: String) -> bool {
            Rule::new(
                &self.rule.to_owned(),
                self.dir_only,
                self.negation
            ).is_match(&path.to_owned())
        }
    }
}
