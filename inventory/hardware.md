# Hardware Inventory

Physical specs for the machines managed by this repo.

## peque (NAS)

Mini PC (Intel NUC-style), IP 192.168.1.67.

- **CPU**: Intel Core i7-6500U
- **RAM**: Up to 16GB DDR3L 1600MHz (2x SO-DIMM)
- **GPU**: Intel HD Graphics 520
- **Storage**:
  - 1x M.2 (256GB SSD — OS drive)
  - 1x 2.5" SATA III (1TB — available internal bay)
- **Ports**: 4x USB 3.0, 1x HDMI, 1x DisplayPort, 1x RJ45 GbE, 1x audio
- **PSU**: 65W adapter
- **Size**: 13x13x5.2 cm, 70g

### Known issue: external USB drive reliability

The data drive (`/dev/sda1`, mounted at `/mnt/external-disk1`) is an external USB drive. It has recurring fsck failures that drop the system into maintenance mode at boot, preventing SSH access.

**Root cause**: USB drives are not designed for 24/7 NAS use — USB power drops and disconnects corrupt the filesystem.

**Fix applied**: fstab entry uses `nofail` and `0 0` (no boot-time fsck) to prevent boot failures.

**Recommended long-term fix**: Replace the external USB drive with an internal 2.5" SATA NAS-rated drive (e.g., WD Red Plus, Seagate IronWolf) in the available SATA bay.
