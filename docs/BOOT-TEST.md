# Native Boot Test

## Preconditions

- Backups and a known Windows recovery path exist.
- The target is an x86-64 UEFI machine.
- The removable device is positively identified.
- The USB already has a healthy GPT/FAT32 volume.
- The diagnostic kernel has been copied to `EFI/BOOT/BOOTX64.EFI`.
- The copied image hash matches the build artifact.
- The host is connected to power.

## Procedure

1. Record the internal disk and USB identities from the running host OS.
2. Fully shut down the host; do not use hybrid sleep if firmware access is unreliable.
3. Leave the qualified USB connected.
4. Open the one-time UEFI boot menu.
5. If necessary, temporarily disable Secure Boot for the unsigned development image.
6. Select the removable UEFI entry. Do not change permanent boot order.
7. Wait for either the pass banner, a kernel panic, or a stable failure screen.
8. Photograph or transcribe the final screen exactly.
9. Power off. The diagnostic PID 1 intentionally provides no shutdown command.
10. Remove the USB and boot Windows normally.
11. Verify Windows storage health and confirm that the internal partition map is unchanged.

## Expected pass banner

```text
=== AWV1 NATIVE BOOT TEST PASSED ===
Linux 7.2.8 reached PID 1 from the USB kernel.
Disk 0 has not been mounted. Power off to end this test.
```

## Failure classification

- USB absent from boot menu: removable-media or firmware-discovery failure.
- Security violation: Secure Boot rejected the unsigned image.
- Immediate return to firmware: EFI-stub execution failure.
- Kernel text followed by panic before PID 1: kernel/hardware/initramfs failure.
- Blank screen with active machine: graphics/console qualification failure.
- Pass banner: Phase 1 kernel boot gate passed; host-storage verification still remains.
