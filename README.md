# tukzedo

A modern, ultra-secure, highly-opinionated linux distro with the following goals.

Main features:

- Based on ZFS.
- The root filesystem is encrypted with native ZFS encryption via transparent TPM2+SecureBoot.
- Each user's filesystem is encrypted with native ZFS encryption and their own PAM-integrated password.
- Immutable OS.
    - The root OS is read-only.
    - System upgrades are 100% all-or-nothing atomic.
    - Previous states can be rolled back to.
        - System version history is automatically pruned based on user-configurable policy.
- Stable rolling release.
   - Always up-to-date
   - Major new release upgrades not a thing.
   - Unlike other rolling releases, not a "testing" distribution.
- Automatic fine-grained ZFS snapshots, and snapshot history pruning.
- Flatpack applications for slightly better security, and absolute minimum upgrade conflict.
- Modern file structure that "abandons" the Linux *Filesystem Hierarchy Standard* (FHS).
    - FHS still exists for compatibility purposes, but is hidden.
    - Users can choose to view the system as a modern filesystem, or the FHS - at will, back and forth at runtime, without a reboot or logout.
        - By default, new users are shown the new filesystem.
        - By default, user `root` is shown the FHS.
