# Safety Model

## Protected assets

- The host's internal storage and existing operating system
- Firmware boot configuration
- User data and recovery paths
- The removable device's pre-existing contents
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
4. requires exactly one mounted FAT32 partition;
5. performs no formatting or partition creation;
6. copies only the named boot image and public metadata;
7. verifies the copied image with SHA-256.

## Residual risks

- Firmware implementations vary and may mishandle removable boot images.
- Disabling Secure Boot reduces boot-chain assurance until signing is implemented.
- A kernel defect can still affect hardware despite the storage-inert init program.
- Human selection in a firmware menu can be wrong.
- Later persistence phases will materially expand the storage threat surface.
