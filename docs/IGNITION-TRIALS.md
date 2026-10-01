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

Candidate 2 build `#4` was built and installed for Physical Trial 2.

- Built and USB read-back SHA-256: `DE36F704867BA9DF8C59F9206FD065263FA59E3D4ADB960DFD2F4F6ED6A3F801`
- Embedded diagnostic PID 1 SHA-256: `41AD1F858232FCECD8CFC9DB4B60C623B895D743E4C55E6B21A3F58F6743934D`
- EFI metadata: x86-64 PE32+ EFI application
- Installer residue after verified replacement: none

These hashes identify the installed candidate; they do not substitute for the still-missing public patch series and full qualified kernel configuration.

## Trial 2 — Candidate 2

Date: **October 1, 2026**

Observed result: **passed Phase 1 Ignition**.

- Firmware launched the removable UEFI image.
- The display presented the exact AWV1 diagnostic PID 1 pass banner.
- Additional settings-like console text appeared below the banner; its exact text was not captured.
- Keyboard input produced no shell behavior, as expected: the diagnostic PID 1 implements only banner output followed by an idle loop.
- The machine was powered off and Windows booted normally afterward.
- Post-trial reconciliation found the internal disk healthy, online, and still identified as the Windows boot/system disk.
- The SanDisk USB remained healthy, online, GPT, and neither boot nor system storage under Windows.
- The built image and USB copy still matched SHA-256 `DE36F704867BA9DF8C59F9206FD065263FA59E3D4ADB960DFD2F4F6ED6A3F801`.
- No installer staging or rollback residue was present.

The observed banner proves EFI-stub execution, kernel initialization, embedded-initramfs execution, diagnostic PID 1 execution, and a working visible-console path on this host. Phase 1 is complete. Phase 2 Habitat remains unstarted.
