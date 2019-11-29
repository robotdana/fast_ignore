#[macro_use]

extern crate helix;

struct Rule {
    rule: str,
    dir_only: bool,
    negation: bool
}

ruby! {
    class FastIgnoreRule {
        struct {
            rule: str,
            dir_only: bool,
            negation: bool
        }

        def initialize(helix, rule: str, dir_only: bool, negation: bool) {
            FastIgnoreRule { helix, rule, dir_only, negation }
        }

        def negation?(&self) -> bool {
            self.negation
        }

        def dir_only?(&self) -> bool {

        }
    }
}
