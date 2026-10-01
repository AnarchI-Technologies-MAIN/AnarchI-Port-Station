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

## Important evidence boundary

Compilation and USB installation do not prove physical boot. Phase 1 remains open until the expected PID 1 banner is observed on target hardware and the host's internal storage is verified unchanged afterward.

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
