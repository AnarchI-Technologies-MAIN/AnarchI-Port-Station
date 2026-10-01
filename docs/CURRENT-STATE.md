# Current State

## Qualified evidence

The AWV1 build reached all of the following milestones on a native Windows host:

1. Linux 7.2.8 `x86_64_defconfig` completed.
2. Kbuild host utilities compiled with MSYS2-native Clang.
3. Target objects compiled with Windows LLVM 22.1.8.
4. `objtool` linked and executed under MSYS2.
5. Both 32-bit and 64-bit x86 VDSO images were generated.
6. The complete configured source tree compiled.
7. `vmlinux`, kallsyms, `System.map`, and module metadata were generated.
8. `arch/x86/boot/bzImage` completed successfully.
9. A second kernel containing the diagnostic initramfs completed successfully.
10. The USB copy was read back and matched the source SHA-256.
11. The resulting image identified as a PE32+ EFI application.
12. Physical Trial 1 produced a stable backlit black screen and no visible banner.
13. Candidate 2 rebuilt with `DRM_SIMPLEDRM`, DRM fbdev emulation, framebuffer console, and simple framebuffer support.
14. Candidate 2 build `#4` embeds `console=tty0 loglevel=7 init=/init` and is installed with matching source/destination SHA-256 `DE36F704867BA9DF8C59F9206FD065263FA59E3D4ADB960DFD2F4F6ED6A3F801`.
15. The embedded static PID 1 was extracted from the linked kernel and matched the independently built SHA-256 `41AD1F858232FCECD8CFC9DB4B60C623B895D743E4C55E6B21A3F58F6743934D`.

## Important evidence boundary

Compilation and USB installation do not prove physical boot. Phase 1 remains open until the expected PID 1 banner is observed on target hardware and the host's internal storage is verified unchanged afterward.

Trial 1 is evidence of a graphics/console qualification failure, not proof that the kernel failed to execute. Candidate 2 has not yet been physically tested.

The public repository does not yet contain a complete kernel-source patch series or the full qualified kernel configuration. The build wrapper alone is therefore insufficient to reproduce the currently installed binary from pristine upstream source. Treat this as an open provenance gate, not a completed reproducible-build claim.

## Portability seams encountered

The native Windows/MSYS2 build required narrow compatibility work around:

- Kbuild host-linker selection;
- Windows drive letters and CRLF dependency files in `fixdep`;
- MSYS header namespace collisions;
- missing `sendfile()` behavior in objtool;
- older MSYS-native libelf APIs;
- PE `.llvm_addrsig` placement;
- Linux-specific `/proc/self/maps` stack labeling;
- missing `copy_file_range()` and `O_LARGEFILE` in a host utility;
- MSYS GNU Make handling of generated VDSO and ASN.1 intermediates;
- an NTFS case collision between `xt_TCPMSS` and `xt_tcpmss` sources and headers;
- selection of GNU `readelf` where the Windows LLVM distribution lacked `llvm-readelf`.

These repairs require cleanup into a reviewable patch series before they should be proposed upstream or treated as generally supported.

## Not published here

- Raw workstation inventories
- Full local build transcripts
- User profile or path inventories
- BitLocker or recovery information
- Authentication material
- Private AnarchI-IP proof records
- Unreviewed binary releases
