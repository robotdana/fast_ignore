#[macro_use]

extern crate helix;

struct Rule {
    negation: bool,
    dir_only: bool,
    rule: str
}

impl Rule {

}

ruby! {
    class FastIgnoreRule {
        def rust() -> &'static str {
            "hi from rust"
        }
    }
}
