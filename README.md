# AnarchI Port-Station

**Portable Workstation System**<br>
**AWV1 — Ignition Candidate 1**

> Carry your system. Command the machine.

AnarchI Port-Station is an experimental portable workstation system intended to move a controlled working environment between compatible computers without making any one host machine the permanent home of that environment.

Port-Station is not presented as a finished operating system, a universal live USB, or a security product. The current release is a narrowly qualified native-boot prototype built around Linux 7.2.8, a removable GPT/FAT32 UEFI device, and a deliberately non-persistent diagnostic initramfs.

## Current state

The current AWV1 milestone has completed these gates:

- Linux 7.2.8 `x86_64_defconfig` generation on native Windows/MSYS2.
- Native Windows-hosted LLVM target compilation with MSYS2 host tools.
- Successful `prepare`, objtool construction, full `vmlinux` link, and `bzImage` generation.
- Successful construction of an embedded, static diagnostic PID 1.
- Successful creation and read-back verification of a removable-media UEFI fallback image at `EFI/BOOT/BOOTX64.EFI`.
- SHA-256 verification between the built image and the USB copy.
- Preservation of the Windows boot configuration and internal disk partition map.

The next unresolved gate is physical native boot testing on the target hardware. Until that succeeds, this repository describes an **Ignition Candidate**, not a boot-qualified workstation.

## What it can do now

- Reproduce the qualified Linux kernel build command on the documented Windows/MSYS2 toolchain.
- Build a PE32+ x86-64 Linux EFI-stub kernel.
- Embed a tiny initramfs that reaches PID 1 without mounting persistent storage.
- Produce a diagnostic boot image that prints an unmistakable pass banner.
- Install that image into the standard removable-media UEFI fallback path on an already prepared FAT32 USB volume.
- Reject Disk 0 and reject non-USB targets in the included installer.
- Verify source and destination images by SHA-256 after copying.
- Preserve the host's permanent boot order by relying on its one-time UEFI boot menu.

## What it cannot do yet

- Provide a persistent workstation root filesystem.
- Preserve user files, packages, secrets, or configuration across boots.
- Prove boot compatibility on hardware that has not been tested.
- Boot with Secure Boot enabled unless the image is signed through a trusted key path.
- Guarantee graphics, Wi-Fi, audio, suspend, touch, cameras, or other device support.
- Update or roll back itself transactionally.
- Encrypt portable workstation state because persistent state does not exist yet.
- Claim universal UEFI, BIOS, CPU, or peripheral compatibility.
- Replace Windows safely or act as an installer for an internal disk.

## What it refuses to do

The project treats refusal as a system property, not a warning label.

- It refuses to select or modify internal Disk 0 during removable-media installation.
- It refuses to format, repartition, or erase a device implicitly.
- It refuses to change the permanent firmware boot order.
- It refuses to mount or write host storage during the current diagnostic boot.
- It refuses to claim a qualification result that has not been observed and recorded.
- It refuses to describe an unsigned development image as Secure-Boot compatible.
- It refuses to publish workstation inventories, credentials, recovery keys, private build logs, or private AnarchI-IP evidence.
- It refuses to call probabilistic behavior deterministic merely because it worked once.
- It refuses to introduce an LLM where a smaller deterministic mechanism can satisfy the requirement.

## What it intends to become

Port-Station intends to make the workstation independent of any one computer. A host should provide compatible hardware; Port-Station should provide the operating environment, verified state, recovery path, and owner-controlled policy.

The intended system properties are:

- deterministic and auditable builds;
- portable, encrypted persistence;
- explicit host-disk isolation;
- hardware discovery with bounded compatibility decisions;
- transactional updates and rollback;
- reproducible workstation provisioning;
- clear degraded modes instead of silent partial failure;
- user-owned keys and recoverable state;
- optional higher-level automation only where deterministic systems are insufficient.

## Qualification phases

### Phase 0 — Forge: complete

Establish a native Windows/MSYS2 kernel toolchain, repair portability seams, generate `defconfig`, complete `prepare`, and produce a Linux 7.2.8 `bzImage`.

### Phase 1 — Ignition: current

Boot the unsigned EFI-stub image from removable media, reach the embedded diagnostic PID 1, display the pass banner, and confirm that internal storage remains untouched.

Exit criteria:

- firmware recognizes the removable UEFI image;
- the kernel initializes on physical hardware;
- PID 1 prints the expected banner;
- no internal volume is mounted or modified;
- Windows still boots normally afterward.

### Phase 2 — Habitat

Introduce a minimal portable root filesystem, shell, hardware inventory, deterministic service startup, and a controlled persistence model.

### Phase 3 — Continuity

Add encrypted persistence, user identity, package manifests, atomic updates, rollback, recovery media, integrity verification, and power-loss testing.

### Phase 4 — Transit

Qualify multiple host classes. Add hardware profiles, explicit compatibility grades, portable networking, graphics fallback, and device-specific recovery paths.

### Phase 5 — Workstation

Deliver the development environment, repositories, editors, toolchains, reproducible provisioning, backup, and migration workflows expected of a daily workstation.

### Phase 6 — Sovereignty

Harden ownership boundaries, signing infrastructure, reproducible releases, measured-boot options, disaster recovery, documentation, and long-duration field qualification.

## Repository layout

```text
boot-test/     Minimal storage-inert PID 1 diagnostic
docs/          Architecture, safety model, status, and test procedure
scripts/       Reproducible build and guarded USB installation tools
```

## First native boot test

Read [docs/BOOT-TEST.md](docs/BOOT-TEST.md) completely before testing. The short version is:

1. Use an x86-64 UEFI machine.
2. Use an already prepared GPT/FAT32 USB device.
3. Install the image with the guarded script, explicitly naming the nonzero USB disk.
4. Fully shut down the host.
5. Use the one-time UEFI boot menu.
6. Disable Secure Boot temporarily if the development image is unsigned.
7. Select the USB without changing permanent boot order.
8. Record the last visible screen and verify Windows afterward.

## Build status

See [docs/CURRENT-STATE.md](docs/CURRENT-STATE.md) for the precise evidence boundary and known portability repairs.

## Security and safety

See [SECURITY.md](SECURITY.md) and [docs/SAFETY-MODEL.md](docs/SAFETY-MODEL.md). Do not test this project on a machine whose recovery path, backups, firmware access, and storage identity you do not understand.

## Licensing and marks

Original repository documentation and tooling are provided under the Apache License 2.0. Linux remains governed by its own upstream licensing, including GPL-2.0-only requirements. This repository does not relicense Linux.

**AnarchI** and **Port-Station** are product and brand identifiers of AnarchI Technologies. The software license does not grant trademark rights.

## Project doctrine

> Hardcoding freedom into the systems of tomorrow.
