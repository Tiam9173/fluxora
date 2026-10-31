# Benchmark Policy

`test/performance/editor_highlight_benchmark.dart` measures how long the
syntax highlighter takes on a 2000-line YAML document. It exists to make a
regression **visible**, not to gate a merge.

## What it is

- **Observation, not a test.** The file's own doc comment says so: it pins the
  current cost so a future change shows up here instead of in a user complaint.
- It prints numbers (`cold` pass, `warm` pass) that a human reads.

## What it is not

- **It is not part of the CI gate.** The file used to be named
  `editor_highlight_benchmark_test.dart`, which meant the bare `flutter test` in
  `.github/workflows/test.yaml` collected and ran it on every push. The
  `expect(warm, lessThan(500))` assertion is a **machine-dependent** number, so
  it could fail for reasons that have nothing to do with the code.
- **The 500 ms bound is not a cross-machine performance standard.** It is the
  ceiling observed on the developer machine that wrote it. Do not quote it as a
  requirement, and do not raise it to make CI pass — CI no longer runs this file.

## Running it

```
flutter test test/performance/editor_highlight_benchmark.dart
```

The `_test` suffix was dropped on purpose: `flutter test` only auto-collects
`*_test.dart`, so the rename removes it from the default run while leaving the
explicit command above working.

## Recording a result

Record, together:

1. `cold` (first pass, no cache) and `warm` (second pass, per-line cache) —
   both in milliseconds.
2. The machine: CPU model, core count, RAM.
3. OS build and whether the machine was on battery or AC.
4. The Flutter/Dart version (`flutter --version`).
5. The commit under test.

A number without its environment is not a result.

## Comparing

- **Only compare runs on the same machine**, same OS, same power state, same
  Flutter version. Same-commit reruns give you the noise floor; anything inside
  it is not a change.
- **Never compare absolute milliseconds across machines.** Different CPUs
  differ by multiples, and that difference says nothing about the code.
- A regression is "same machine, same environment, meaningfully slower than the
  previous commit", not "slower than 500".

## Coverage note

Because the file is no longer collected, **CI no longer compiles or runs it**.
A syntax error or a broken API call in the benchmark will not be caught
automatically. Run it manually when touching the highlighter, and before a
release that includes highlighter changes.
