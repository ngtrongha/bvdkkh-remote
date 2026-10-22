# Hardware inventory and background Windows updates

The client uploads hardware identifiers in the existing `hardware_info` JSON field. The API already persists that field and WebAdmin already reads CPU, RAM, storage, motherboard, BIOS, and monitor serials. No database migration or API contract change is needed.

GPU entries now include `SerialNumber`, `UUID`, and `PNPDeviceID` separately. NVIDIA serials and UUIDs are queried through an already installed `nvidia-smi`, with a five-second timeout and no console window. Only a unique vendor/model match is associated with a WMI GPU. Unsupported serials remain empty; identical GPU model names are not guessed. AMD/Intel GPU serials are not exposed by this collector. CPU serial availability depends on firmware; ProcessorId is not substituted for a serial.

Storage serial collection falls back from `Win32_DiskDrive` to `Win32_PhysicalMedia` by physical device path. When available, the Storage WMI provider identifies SSD/HDD by matching the serial.

Installed Windows clients enable automatic updates when the option has never been set. An explicit disabled setting is retained. Checks run after 30 seconds on startup, then daily; failed checks retry after 30 minutes. The source is `ngtrongha/bvdkkh-remote-release`. Only newer stable releases containing the exact uploaded artifact, a nonzero size, and a valid SHA256 digest are eligible. Drafts, prereleases, incomplete uploads, and releases for another Windows channel/architecture are skipped.

Windows 7/8 Flutter builds select `rustdesk-VERSION-win7-ARCH.exe` or `.msi`; Windows 10/11 Flutter builds select `rustdesk-VERSION-ARCH.exe` or `.msi`; Sciter builds select `rustdesk-VERSION-ARCH-sciter.exe`. The installed executable architecture is preserved. The updater verifies size and SHA256 before using the existing privileged update installer.

Downloads can complete during a remote session. The scheduler retains the verified artifact, checks connection state every minute without querying GitHub again, and installs only when the existing incoming/outgoing session guards report idle. Installation rechecks the cached file's integrity. No update is deployed by these source changes alone: clients need a newly built release containing the changes first.

## Verification

- `powershell.exe -NoProfile -NonInteractive -File res/test_windows_inventory.ps1`: passed. Exercises actual collection blocks with GPU and disk fixtures.
- The complete embedded inventory script parsed and executed on the development Windows machine, returning CPU, RAM, physical storage and GPU inventory.
- WebAdmin: `flutter test --no-pub test/features/devices/device_model_test.dart`: 7 passed.
- WebAdmin: targeted `dart analyze`: no issues. Application launched in Edge and hot reload succeeded.
- New Rust unit tests cover channel/architecture filenames and the newest eligible stable release. All four edited/new Rust source files passed Tree-sitter syntax parsing. Rust unit tests and the full Windows client build were **not run**, because the local Rust toolchain is unavailable; attempted toolchain acquisition was stopped due to slow downloads.
- GitHub release assets were inspected read-only: v1.5.17 has modern Windows packages, while v1.5.16 includes the Windows 7 x64 packages. Both provide SHA256 digests.

## Existing runtime paths changed

| File | Necessary behavior change |
| --- | --- |
| `src/common.rs` | Add disk serial fallback and GPU identifiers to the existing inventory; select a release ready for this client and reject update URLs outside the designated owner. |
| `src/updater.rs` | Enable unset Windows update preferences and retain downloaded artifacts while sessions are active; retry idle detection every minute. |
| `src/updater/artifact.rs` | Preserve executable architecture, choose Windows 7 filenames, require a ready release asset and SHA256, and restrict the designated release repository owner. |
| WebAdmin `device_detail_dialog.dart` | Display GPU serial/UUID/PnP identifiers and accurately label absent CPU serials. |

Backend persistence and transport reuse their existing paths. The pre-existing WebAdmin `pubspec.yaml` working-tree changes were preserved.
