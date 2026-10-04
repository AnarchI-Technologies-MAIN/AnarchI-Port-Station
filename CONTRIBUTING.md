# Contributing

Contributions should preserve the project's deterministic and default-deny character.

Before proposing a change:

1. State the invariant or failure mode being addressed.
2. Keep hardware and storage assumptions explicit.
3. Include a reproducible test.
4. Do not weaken Disk 0, non-USB, boot-disk, system-disk, non-GPT, ambiguous-FAT32, formatting, or boot-order refusals.
5. Do not submit credentials, recovery material, personal inventories, proprietary logs, or private evidence.
6. Separate observed qualification results from projections.
7. Preserve source EFI validation, source and target identity revalidation, volume-GUID addressing, write-through staging, rollback-copy verification, installed-image verification, and restoration verification before changing the installer mutation path.

Kernel-derived changes must retain applicable upstream licensing and attribution.
