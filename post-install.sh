#!/bin/bash
set -e

if flatpak remotes | grep -q '^fedora'; then
flatpak remote-delete fedora
sleep 2
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi
