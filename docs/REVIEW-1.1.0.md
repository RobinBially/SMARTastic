# SMARTastic 1.1.0 review and verification

Review baseline: `da2284f`, including the pre-existing local logo/icon changes.
Scope: the complete application, not just the initial two-file working diff.
Review perspectives: data correctness, process/error handling and concurrency,
UI semantics/accessibility, packaging/signing and release recovery.

The first external-provider review attempts failed before execution. Three
independent native reviewers subsequently checked the implementation. Their
concrete findings were checked against code, tests and, where available, hardware.

## Corrected defects

| ID | Original behavior / reproducible scenario | Change and evidence |
| --- | --- | --- |
| R1 | ATA columns were parsed from the end of each text row, confusing normalized values and raw counters. | Parse smartctl JSON; tests assert 18,342 power-on hours and 654 cycles independently of normalized values. Temperature uses smartctl's decoded field. |
| R2 | Nonzero smartctl status caused all output to be discarded, including useful measurements returned with health warnings or failed optional commands. | Preserve valid JSON and surface diagnostics. Verified with the attached Apple SSD returning status 4 for an optional log failure. |
| R3 | A failing SSD with little reported wear could receive a healthy score. Missing data became zero wear/zero errors/full spare. | Optional metrics and explicit good/warning/critical/unknown states; failure, NVMe critical warning, low spare and exhausted endurance take precedence. |
| R4 | Numeric text parsing mixed thousands separators with bracketed capacity labels; raw NVMe units used the wrong byte multiplier. | Parse numeric JSON values and use exactly 512,000 bytes per NVMe data unit. Regression tests verify capacity and traffic quantities. |
| R5 | Apple models were always excluded. Disk enumeration stopped at disk20 and tested unrelated plist booleans. Missing serials could merge different drives. | Enumerate diskutil's physical WholeDisks with no fixed index limit or vendor exclusion; use device paths as identities. Real internal Apple and external NVMe drives are present. |
| R6 | Waiting for process exit before draining pipes could deadlock on large output; a stuck device had no timeout. | File-backed output, 12-second per-command deadlines and TERM/KILL escalation. Tests cover output larger than a pipe buffer and a timed-out process. |
| R7 | Repeated timer starts could leave multiple timers; selection was not reconciled after unplugging a drive. | MainActor model, idempotent timer setup and selection reconciliation. Tests cover disconnect, empty scan, concurrent refresh and preserving the last snapshot after errors. |
| R8 | During the overhaul, blindly adding ATA attribute 198 treated Host_Reads_GiB on some healthy SSDs as errors. | Use smartctl's named attribute semantics. Regression test covers the vendor read counter; confirmed against smartmontools' drive database. |
| R9 | Packaging copied debug output and put resources at the bundle root; there was no trusted release signature. | Versioned release build, embedded Resources bundle resolver, Universal binary, Developer ID signing with Hardened Runtime and timestamp. Both architectures checked. |
| R10 | The initial release workflow could not resume after Apple timeout or a later tap failure. | Restore the same submission and original build number; recover executable modes from submission ZIP. Existing public releases are matched to the exact source commit, verified and continued at the tap step. |

## UI and documentation corrections

- Native selectable sidebar rows replace mouse-only card gestures; search filters
  by model or interface. First scan automatically selects a drive.
- Consistent system typography, compact metric cards and restrained status colours
  replace multiple competing rings and gradients. Both four-metric sections use
  one row when space permits and two columns in narrow windows.
- The title and opaque toolbar strip are removed. The scroll view and its scroll
  indicator extend behind the transparent window chrome. Circular actions float
  at the top right with equal 24-point margins; macOS 26 uses the native glass
  button style, with native bordered buttons on macOS 14–15.
- The arbitrary HDD score and calendar failure-date forecast were removed.
  Remaining rated SSD endurance is labelled and explained accurately.
- Unavailable values render as a dash, with an explanation. SMART-unavailable
  guidance no longer asserts a USB hardware limitation without evidence.
- Warning indicators remain visible inside metric cards; selected sidebar text
  has appropriate contrast. Singular drive counts use the correct translation.
- A sun/moon appearance switch in the sidebar replaces the dropdown and persists
  across launches. System is the default and can be restored with a right-click. The screenshot-only `--light` argument
  provides a transient demo override.
- New vector logo, complete macOS ICNS set and screenshots replace the old
  artwork. Screenshots show labelled synthetic data, not private drive serials.
- JSON export omits serial-number fields, includes sample time and schema version,
  and presents save failures. Diagnostic free text should be reviewed before sharing.
- README now matches the metrics, installation prerequisites, refresh intervals,
  report export, languages, appearance controls and release status.

## Executed verification

- 17 Swift XCTest tests passed, including a separately enabled real hardware scan.
- Native app launch, drive selection, search, healthy/warning/unavailable states,
  JSON export through the native save dialog and content verification.
- Appearance changed using the live sun/moon switch; selection persisted after restart.
  Switching from Light back to System was verified to restore dark appearance
  throughout the window. Window positioning during capture was corrected before
  saving the final screenshots.
- Light/dark screenshots were inspected. Final README images are
  `assets/screenshot-light.png`, `assets/screenshot-dark.png` and
  `assets/screenshot-warning.png`.
- Universal arm64/x86_64 release build; local Developer ID signature verification.
  Minimum binary target is macOS 14.0. The standalone macOS 27 Command Line Tools
  failed due to a missing SwiftUI macro plugin; full Xcode succeeded.
- 11 offline Python regression tests cover release creation and recovery, including safe pre-build retries and refusing ambiguous submission state.
- Shell syntax and Python syntax checked. Pinned GitHub Action commits exist.
- GitHub Actions with Xcode 26.3 passed tests and built Universal. Its first
  architecture-verification step exposed a lipo argument-order compatibility
  issue. All scripts now verify the portable lipo -archs output through the
  shared check-architectures.sh helper.

## Limits and pending distribution

- No directly readable ATA drive or Intel Mac was available. ATA semantics use
  fixtures plus the smartmontools drive database; a Universal build is not an
  Intel runtime test.
- The process timeout bounds each command, not the total duration of scanning
  many slow drives. Scans preserve diskutil basic information on SMART failures.
- Developer ID identity exists and signs locally. The app was previously ad hoc
  signed. Local notarization authentication currently returns HTTP 401.
- GitHub Actions release secrets are not configured in SMARTastic. A complete
  existing signing setup is available in Locomni; use of that separate repository
  is awaiting the user's choice. No notarization submission, public release or
  Homebrew cask publication is claimed yet.
- CI signing/notary/tap recovery paths have been reviewed and prepared; an actual
  successful end-to-end public release remains the acceptance gate.
