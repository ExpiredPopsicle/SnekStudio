#!/bin/bash

set -e

apt update
apt install -y flatpak flatpak-builder binfmt-support qemu-user-static

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# install platform and sdk for both aarch64 and x86_64 so we can build both flatpaks
flatpak install -y \
    org.freedesktop.Sdk/x86_64/24.08 \
    org.freedesktop.Platform/x86_64/24.08 \
    org.freedesktop.Sdk/aarch64/24.08 \
    org.freedesktop.Platform/aarch64/24.08