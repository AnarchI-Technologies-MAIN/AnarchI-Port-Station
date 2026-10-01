# Safety Model

## Protected assets

- The host's internal storage and existing operating system
- Firmware boot configuration
- User data and recovery paths
- The removable device's pre-existing contents outside the explicitly authorized fallback image path
- Secrets, credentials, and private project evidence

## Default-deny boundaries

The current toolchain treats these actions as outside normal operation:

- selecting Disk 0;
- selecting a non-USB disk;
- repartitioning or formatting automatically;
- editing the permanent firmware boot order;
- mounting host filesystems from the diagnostic initramfs;
- installing to internal storage;
- silently continuing after target identity changes.

## Installer invariants

The guarded USB installer:

1. requires an explicit disk number;
2. rejects Disk 0;
3. requires Windows to report the target bus as USB;
4. rejects boot, system, offline, read-only, and non-GPT disks;
5. requires exactly one mounted FAT32 partition and stable disk, partition, and Windows volume identities;
6. requires an executable, non-DLL x86-64 PE32+ EFI application as input;
7. snapshots disk, partition, volume, and source identity and revalidates them immediately before mutation;
8. addresses mutation through the qualified volume GUID instead of a mutable drive-letter path;
9. performs no formatting or partition creation;
10. stages and flushes the candidate before replacing the fallback image;
11. verifies the rollback copy before replacement;
12. preserves the live image on staged or rollback-copy verification failure;
13. verifies the installed image and, if installation verification fails, restores and verifies the prior image with SHA-256.

## Residual risks

- Firmware implementations vary and may mishandle removable boot images.
- Disabling Secure Boot reduces boot-chain assurance until signing is implemented.
- A kernel defect can still affect hardware despite the storage-inert init program.
- Human selection in a firmware menu can be wrong.
- Removal, power loss, failing media, or a hostile privileged local actor can still interrupt filesystem metadata updates after qualification; staging and rollback reduce this risk but do not make FAT32 power-loss atomic.
- Later persistence phases will materially expand the storage threat surface.
