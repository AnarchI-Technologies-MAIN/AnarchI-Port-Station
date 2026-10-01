# Ignition Trial Record

## Trial 1 — Candidate 1

Observed result: **failed visible-output gate**.

- Firmware attempted the removable UEFI entry.
- The panel backlight activated, but no text or graphics appeared during a ten-minute observation window.
- Windows remained bootable afterward with the USB attached.
- The installed image matched the build artifact by SHA-256.
- Secure Boot was disabled.
- Reconciliation found that `DRM_SIMPLEDRM`, DRM fbdev emulation, framebuffer console, and simple framebuffer support were absent.

This result does not establish whether the kernel reached PID 1; Candidate 1 had no qualified visible-console path on the tested UEFI-GOP hardware.

## Candidate 2 repair

Candidate 2 adds:

- EFI/simple framebuffer console support;
- DRM fbdev emulation and framebuffer console;
- `console=tty0 loglevel=7 init=/init` as the built-in command line;
- a diagnostic PID 1 banner limited to facts that PID 1 itself can establish.

Candidate 2 build `#4` is built and installed but has not yet undergone a physical boot trial.

- Built and USB read-back SHA-256: `DE36F704867BA9DF8C59F9206FD065263FA59E3D4ADB960DFD2F4F6ED6A3F801`
- Embedded diagnostic PID 1 SHA-256: `41AD1F858232FCECD8CFC9DB4B60C623B895D743E4C55E6B21A3F58F6743934D`
- EFI metadata: x86-64 PE32+ EFI application
- Installer residue after verified replacement: none

These hashes identify the installed candidate; they do not substitute for the still-missing public patch series and full qualified kernel configuration. Phase 1 remains open.
