<!--
Every change starts as an issue that has been discussed. If there is no issue
behind this PR, please open one first — see CONTRIBUTING.md. The only exception
is an obvious typo or a broken link in the docs.
-->

Closes #

## What this changes

<!-- One or two sentences. What behaviour is different after this PR? -->

## Why

<!--
The reasoning, not the diff. If you made a judgement call between two
approaches, say which and why — that answer usually belongs in a code comment
too.
-->

## How it was verified

<!--
For a bug fix: a regression test must FAIL before the fix and PASS after it.
Say what you reverted and which tests went red — a test that passes either way
protects nothing, and they are easy to write by accident.
-->

## Checklist

- [ ] There is a discussed issue behind this PR, linked above
- [ ] `flutter analyze` is clean
- [ ] `flutter test` is clean
- [ ] Behavioural changes have a test that fails without the fix
- [ ] `flutter build web` still compiles (only if this touches anything platform-facing)
- [ ] No new pub dependency and no Flutter plugin was added
- [ ] `SketchSerializer.schemaVersion` is untouched, or the bump was agreed in the issue
- [ ] Chrome colours come from `Theme.of(context).colorScheme`, not `AppColors.*`
- [ ] This PR does one thing

## Anything the reviewer should look at closely

<!--
Optional. A part you were unsure about, a trade-off you want a second opinion
on, or something you deliberately left out of scope.
-->
