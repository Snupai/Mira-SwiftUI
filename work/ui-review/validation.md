# Native macOS UI validation

Implemented October 8, 2026. The app now uses a native selectable sidebar, destination titles, toolbar actions, scoped search, native status controls, and native sheet actions. Theme colors stay on content and form surfaces. No custom glass layer was needed.

## Build evidence

- Xcode 26.6; Swift 6.3.3; macOS SDK 26.5; runtime macOS 27.0.
- `swift build` passed.
- `./bundle.sh` passed and created `Mira.app` with the existing bundle/signing workflow.
- `codesign --verify --deep --strict Mira.app` passed.
- Mach-O `LC_BUILD_VERSION` and the bundle plist both retain macOS 14.0 as the minimum version.
- `git diff --check` passed.
- The original SwiftPM cache contained an artifact path from an old checkout. The local cache path was repaired; dependency versions and package files were unchanged.

## Runtime evidence

A separate foreground bundle (`dev.mira.ui-review`) was built from disposable source copies under `/tmp`. Its test-only substitutions used an in-memory SwiftData container, sample records, an ephemeral encryption key, a separate theme directory, no legacy loading/migration, and a stubbed CloudKit status check. These substitutions are absent from the application diff. The production bundle was built but not launched against personal data.

Verified through the native accessibility tree and screenshots:

- Initial Invoices destination; Dashboard, Invoices, Clients, and Settings; existing Command-1/2/3/comma navigation.
- Sidebar hide/show from its native toolbar control; the standard sidebar commands are retained in View.
- Invoice and client toolbar entry points, Command-N, and the shortcuts sheet.
- Independent invoice/client queries survive section switches. Invoice Draft selection and Oldest sorting survive section switches.
- Invoice search combined with Paid filtering shows no matches; Clear filters restores all records and clears search. Client unmatched search and Clear search work.
- Tab reaches the native search field. New actions and the sort menu have accessible labels.
- Saving a disposable client updates the client query/list. Saving a disposable invoice with a client and line item updates the invoice query/list and displayed count.
- Client editor, invoice editor, client picker, quick client editor, and shortcuts sheet have native titles/actions. Quick editor cancellation returns to the picker; selecting a client returns to the invoice editor.
- Default, Catppuccin, and a custom JSON palette loaded from the isolated theme directory were inspected in light/dark. Content remains legible while system navigation chrome stays adaptive.
- Invoice layout and its toolbar fit a 760-point-wide window. Baseline captures used the original wider shell.
- SwiftData list rows now resolve client names and record counts from the same data source used by filtering.

## Evidence images

Before/after captures are in this directory. Compare `before-invoices.png` with `after-default-dark-invoices.png`, and `before-client-editor.png` with `after-client-editor.png`. Light and custom palette captures are named explicitly. Baseline captures cover all four destinations and the invoice/client editors in the initial dark appearance, plus Catppuccin invoices.

## Coverage limits

- macOS 14 runtime testing is unavailable on this host. All added APIs support the deployment target; no macOS 26-only API or fallback branch was required.
- VoiceOver speech, OS Increase Contrast/Reduce Transparency modes, every theme/sheet cross-product, and interactive sidebar divider resizing were not fully exercised. No custom transitions were added.
- CloudKit, migrations, production disk persistence across relaunch, PDF output, encryption/keychain integration, and the actual theme-import file dialog were not exercised by the disposable UI harness. Their implementations were unchanged. The custom JSON palette was loaded through the existing theme loader.
- Search is keyboard-accessible with Tab; no new Command-F shortcut was added.

## Run workflow

The Codex Run action invokes `./script/build_and_run.sh`, which stops Mira, calls the existing `bundle.sh`, and launches the resulting foreground app. Optional modes support verification, LLDB, and logs. This normal Run action uses the application's real data; the disposable review setup above was only used for validation.

## Optional Liquid Glass controls

A saved `mira.liquidGlassEnabled` preference is now exposed by the shared appearance picker in Settings and onboarding. It defaults to off. On macOS 26+, enabling it applies native glass-prominent styling to New Invoice/New Client, editor Save actions, and onboarding Continue/preview buttons. Turning it off restores automatic or bordered-prominent native styles. Native navigation chrome remains controlled by macOS.

The macOS 26 API is availability-guarded; older systems display a disabled toggle and use standard controls. Reduce Transparency bypasses the optional glass style while retaining the saved preference.

Debug/release builds passed. Disposable runtime checks verified the initial off state, Settings enablement, the changed invoice toolbar button, persistence through app restart into onboarding, the live preview, and disabling the option. Captures are `glass-settings-enabled.png`, `glass-invoices-enabled.png`, and `glass-onboarding-enabled.png`/`glass-onboarding-disabled.png`. macOS 14 and the OS Reduce Transparency appearance were not exercised at runtime.
