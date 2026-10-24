# hyprzite

A custom [Bazzite](https://bazzite.gg) image (NVIDIA, open kernel modules) with
[Hyprland](https://hyprland.org) and the dependencies for end-4's
[illogical-impulse dotfiles](https://github.com/end-4/dots-hyprland) baked in.
Built daily from the [Universal Blue image template](https://github.com/ublue-os/image-template).

What's added on top of `bazzite-nvidia-open:stable`:

- Hyprland and every dependency group from end-4's
  [Fedora dependency list](https://github.com/end-4/dots-hyprland/blob/main/sdata/dist-fedora/feddeps.toml),
  including the prebuilt `quickshell-git` and `matugen` packages
- [sddm-astronaut-theme](https://github.com/Keyitdev/sddm-astronaut-theme) (`hyprland_kath`) on the login screen
- uinput and ydotool set up for the dotfiles' virtual keyboard
- `ii-setup`: installs or updates the dotfiles for your user, and adds NVIDIA and
  fullscreen-VRR defaults to `~/.config/hypr/custom/`

## Installing

From any Fedora Atomic desktop (Kinoite, Silverblue, Bazzite, …):

```bash
# First switch to the unsigned image so the signing policy gets installed
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/teddybusted/hyprzite:latest
systemctl reboot

# Then move to the signed image
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/teddybusted/hyprzite:latest
systemctl reboot
```

Then, logged in as your user:

```bash
ii-setup
```

Log out and pick **Hyprland** on the login screen (not the UWSM entry).
KDE Plasma stays available as a fallback session.

## Updating

Updates install automatically in the background like on Bazzite; `rpm-ostree upgrade`
forces one. Run `ii-setup` again to update the dotfiles. Roll back a bad update with
`sudo rpm-ostree rollback`.
