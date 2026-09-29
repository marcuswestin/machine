# Tart on this machine

`modules/apps.nix` installs `cirruslabs/cli/tart` through Homebrew. Tart has no
host-wide preference file to import here. The current `~/.tart` contains OCI
image caches and no local VMs, so there are no VM resource settings to preserve.

Tart stores CPU, memory, display, and disk settings per VM. Create or clone a VM,
then use `tart set <name> ...` if a workflow needs specific resources. Keep that
workflow's VM configuration beside the workflow that creates it, rather than
copying `~/.tart` into this repo. VM disks, downloaded images, and registry
credentials are machine-local data and are not tracked.

The Homebrew formula suggests a shorter macOS Internet Sharing DHCP lease for
hosts that create many VMs daily. This repo does not change that system-wide
setting: it is currently unset on this Mac, and Tart does not require it for
installation or ordinary VM use.
