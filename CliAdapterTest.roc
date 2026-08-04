module []

import CliAdapter

expect
    CliAdapter.parseArgs([]) == Ok(Run({ paths: [".env"], policy: PreserveExisting }))

expect
    CliAdapter.parseArgs([".env", ".env.local"]) == Ok(Run({ paths: [".env", ".env.local"], policy: PreserveExisting }))

expect
    CliAdapter.parseArgs(["--overload", ".env"]) == Ok(Run({ paths: [".env"], policy: OverrideExisting }))

expect
    CliAdapter.parseArgs(["--", "--literal.env"]) == Ok(Run({ paths: ["--literal.env"], policy: PreserveExisting }))

expect
    CliAdapter.parseArgs(["--help"]) == Ok(Help)

expect
    CliAdapter.parseArgs(["-h"]) == Ok(Help)

expect
    CliAdapter.parseArgs(["--wat"]) == Err(UnknownFlag("--wat"))

expect
    CliAdapter.fakeFilesFromSources([{ path: ".env", content: "FOO=bar" }]) == [{ path: ".env", source: File("FOO=bar") }]

expect
    CliAdapter.applyConfig(
        { paths: [".env"], policy: PreserveExisting },
        [{ path: ".env", source: File("FOO=bar") }],
        [{ key: "FOO", value: "existing" }],
    )
    == Ok([{ key: "FOO", value: "existing" }])

expect
    CliAdapter.applyConfig(
        { paths: [".env"], policy: OverrideExisting },
        [{ path: ".env", source: File("FOO=bar") }],
        [{ key: "FOO", value: "existing" }],
    )
    == Ok([{ key: "FOO", value: "bar" }])
