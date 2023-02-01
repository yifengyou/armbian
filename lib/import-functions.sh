#!/usr/bin/env bash

## yifengyou: 加载所有function函数，供后续使用
while read -r file; do
	# shellcheck source=/dev/null
	source "$file"
done <<< "$(find "${SRC}/lib/functions" -name "*.sh")"

return

## yifengyou find functions -name "*.sh"

functions/bsp/bsp-cli.sh
functions/bsp/bsp-desktop.sh
functions/bsp/utils-bsp.sh
functions/cli/cli-entrypoint.sh
functions/cli/utils-cli.sh
functions/compilation/atf.sh
functions/compilation/debs.sh
functions/compilation/kernel-debs.sh
functions/compilation/kernel.sh
functions/compilation/patch/kernel-bootsplash-and-drivers.sh
functions/compilation/patch/patching.sh
functions/compilation/patch/drivers_network.sh
functions/compilation/uboot.sh
functions/compilation/utils-compilation.sh
functions/configuration/aggregation.sh
functions/configuration/config-desktop.sh
functions/configuration/interactive.sh
functions/configuration/main-config.sh
functions/configuration/menu.sh
functions/extras/buildpkg.sh
functions/extras/fel.sh
functions/extras/installpkg.sh
functions/general/chroot-helpers.sh
functions/general/cleaning.sh
functions/general/downloads.sh
functions/general/git.sh
functions/host/basic-deps.sh
functions/host/host-utils.sh
functions/host/prepare-host.sh
functions/image/fingerprint.sh
functions/image/initrd.sh
functions/image/loop.sh
functions/image/rootfs-to-image.sh
functions/image/partitioning.sh
functions/logging/logging.sh
functions/logging/runners.sh
functions/logging/traps.sh
functions/main/build-tasks.sh
functions/main/rootfs-image.sh
functions/main/config-prepare.sh
functions/rootfs/apt-install.sh
functions/rootfs/apt-sources.sh
functions/rootfs/boot_logo.sh
functions/rootfs/create-cache.sh
functions/rootfs/customize.sh
functions/rootfs/distro-agnostic.sh
functions/rootfs/distro-specific.sh
functions/rootfs/post-tweaks.sh
functions/rootfs/rootfs-desktop.sh