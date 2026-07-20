# Contributing

Use Flutter 3.44.6 through FVM. Create focused changes with tests, then run:

```shell
fvm dart format .
fvm dart analyze
fvm dart test
```

Generator changes should include temporary-directory tests for paths, content, conflicts, dry runs, and repeated generation. Do not weaken overwrite protection or make unsupported security claims.
