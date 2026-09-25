# Choosing a route

Which processor a local model runs on, and what happens when that cannot work. The rules live in
`EngineRouter`, a pure function; every example on this page is a case in
`test/engine_router_test.dart`.

## The question

A job names a local model and what to run it on: **Auto**, the **CPU**, or one named route. The
device offers some routes for that model's packages — each an adapter, a backend and a processor —
with a check result for each. The router answers with one route to run on, or with an error code
saying why none can, and with the reason each other route was passed over, so the pages can say why
a route is not offered instead of hiding it.

Three promises bound every answer:

1. **The model is never substituted.** Only the chosen record's own packages are considered. A job
   that asked for Whisper large-v3 does not quietly run on turbo, and never on Parakeet.
2. **A fallback happens only within the user's policy**, and it is returned as its own decision —
   from, to and why — which the job records.
3. **Auto never picks a route it has no grounds to trust** (decision D20 of the local-models plan).

## The rules, in order

1. **Language.** A model with a language list takes a job only if every requested language is on
   it, by primary subtag (`zh-TW` is Chinese). Parakeet lists 25 European languages, so a job in
   Chinese, Japanese or Korean fails with `UNSUPPORTED_LANGUAGE` rather than reaching it. A model
   with no list takes any language.
2. **This model's routes.** Routes whose model or package is not the record's are ignored. With none
   left: `MODEL_MISSING` when this build has an adapter for one of the record's packages (adapters
   only describe routes for installed packages, so "nothing installed" looks like "no routes"), and
   `BACKEND_NOT_BUILT` otherwise.
3. **Usable routes.** A route is passed over when its package is not installed (`notInstalled`), its
   backend or driver is missing (`unavailable`), its check here crashed (`crashed`) or failed
   (`checkFailed`), or the job needs segment times it does not keep (`lacksTimestamps`).
4. **The request.**
   - **CPU**: the best usable CPU route — one that passed its check before one not yet checked, then
     one tested here, then the better evidence.
   - **A named route**: that route if usable; otherwise the fallback policy (below), with the reason
     the route cannot run.
   - **Auto**: the rule in the next section.

A chosen route that has not been checked under its current key is returned with `needsSmokeTest`;
the job runs the check first and routes again if it failed.

## Auto

Auto considers accelerator routes (GPU and NPU) that passed their check on this device, and takes one
only when:

- this project **tested it on this kind of device**; or
- its evidence is **A** or **B**, and in its check it ran **faster than the CPU route** did in its
  own. An unknown speed on either side is not a win.

An untested **E** or **U** route is never taken by Auto, however fast its check was; it runs only when
the user names it. Among the candidates, a route tested here comes first, then the faster check,
then the better evidence, then the route key, so the choice is stable. With no candidate, Auto takes
the CPU route — the floor on every device, tested here or not. With no usable CPU route either, the
job fails.

### Worked examples

| Routes on this device (check result, speed as seconds per second of audio) | Asked for | Result |
|---|---|---|
| CPU (passed, 0.5, tested); GPU E (passed, 0.9, tested) | Auto | GPU — tested here outranks speed |
| CPU (passed, 0.5); GPU A or B (passed, 0.2) | Auto | GPU — graded and faster |
| CPU (passed, 0.5); GPU B (passed, 0.8) | Auto | CPU — GPU `notFasterThanCpu` |
| CPU (passed, 0.5); GPU E or U (passed, 0.01) | Auto | CPU — GPU `untestedForAuto` |
| CPU (passed, speed unknown); GPU A (passed, 0.1) | Auto | CPU — nothing to compare |
| CPU (passed); GPU (not checked, tested) | Auto | CPU — GPU `notChecked` |
| CPU (passed); OpenCL (passed, 0.4, tested); QNN A (passed, 0.1) | Auto | OpenCL — tested here first |
| CPU (not checked) | Auto | CPU, after its check |
| CPU (failed); GPU E (passed, 0.1) | Auto | fails — never an untested E route |
| CPU; GPU E (passed) | that GPU | the GPU — the user chose it |

## Fallback

When the route asked for cannot run — before the job, or partway through it — the device-local
fallback policy decides:

- `sameModelOnCpu` (the default): the CPU route of the same model, recorded as a fallback;
- `none`: the job fails with the route's error code;
- `systemRecognizer`: the operating system's recogniser, a route of adapter `system` that serves no
  particular model (later milestone).

Partway through a job, only a **route problem** can be answered — `BACKEND_NOT_BUILT`,
`DRIVER_MISSING`, `DEVICE_UNAVAILABLE`, `MODEL_COMPILE_FAILED`, `DEVICE_LOST`, `ROUTE_CRASHED`, or
`OUT_OF_MEMORY` on an accelerator. A damaged model or an unsupported language would fail on the CPU
too, so it fails the job; a failure on the CPU itself has nowhere further to go. The window that
failed runs again on the fallback route, and the fallback records the window it happened at.

## The check

A route's smoke test transcribes a short clip with known words. Its text is compared with the
expected words after lower-casing and removing punctuation, as one minus the word error rate; a
route **passes at 0.8 or above** (`smokeTestMinSimilarity`). That lets a model spell a number or
split a compound differently and still fails one that produced another sentence, or nothing — which
is what a broken GPU kernel usually produces. The check also records the route's speed, which is what
Auto compares.

The result is filed under the route's six-part key (adapter version, model hash, OS version, driver
version, processor, precision), so any of those changing asks for a new check.

## Tested on this kind of device

Routes this project has verified on real hardware of a device class, with the acceptance list of
`PLAN.md` §7 and a record in [`local-asr-support-matrix.md`](../local-asr-support-matrix.md). An
adapter sets `testedHere` on a route from this table and from nothing else.

| Device class | Adapter | Backend | Verified |
|---|---|---|---|
| — | — | — | nothing yet: no engine is compiled in before L1 |

Every other route is unverified support.
