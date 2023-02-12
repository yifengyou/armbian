#!/usr/bin/env bash
###############################################################################
#
# build_task_is_enabled()
#
# $1: _taskNameToCheck - a single task name to check for BUILD_ONLY enablement
# return:
#   0 - if BUILD_ONLY is empty or if the task name is listed by BUILD_ONLY
#   1 - otherwise 
#
build_task_is_enabled() {
	# remove all "
	local _taskNameToCheck=${1//\"/}
	local _buildOnly=${BUILD_ONLY//\"/}
	# An empty _buildOnly allows any taskname
	# yifengyou: 如果指定了buildonly则仅编译部分，否则都编译
	[[ -z $_buildOnly ]] && return 0
	_buildOnly=${_buildOnly//,/ }
	for _buildOnlyTaskName in ${_buildOnly}; do
		[[ "$_taskNameToCheck" == "$_buildOnlyTaskName" ]] && return 0
	done
	return 1
}

###############################################################################
#
# build_validate_buildOnly()
#
# This function validates the list of task names defined by global
# variable BUIDL_ONLY versus the locally defined constant
# list __all_valid_buildOnly.
#
# In case of future extensions, please maintain the list of valid task names
# only here.
#
build_validate_buildOnly() {
	# constant list of all valid BUILD_ONLY task names - can be :comma: or :space: separated
	local _all_valid_buildOnly="u-boot kernel armbian-config armbian-zsh plymouth-theme-armbian armbian-firmware armbian-bsp chroot bootstrap"
	# remove all "
	local _buildOnly=${BUILD_ONLY//\"/}
	# relace all :comma: by :space:
	_all_valid_buildOnly=${_all_valid_buildOnly//,/ }
	_buildOnly=${_buildOnly//,/ }
	[[ -z $_buildOnly ]] && return
	local _invalidTaskNames=""
	for _taskName in ${_buildOnly}; do
		local _isFound=0
		for _supportedTaskName in ${_all_valid_buildOnly}; do
			[[ "$_taskName" == "$_supportedTaskName" ]] && _isFound=1 && break
		done
		if [[ $_isFound == 0 ]]; then
			[[ -z $_invalidTaskNames ]] && _invalidTaskNames="${_taskName}" || _invalidTaskNames="${_invalidTaskNames} ${_taskName}"
		fi
	done
	if [[ -n $_invalidTaskNames ]]; then
		display_alert "BUILD_ONLY has invalid task name(s):" "${_invalidTaskNames}" "err"
		display_alert "Use BUILD_ONLY valid task names only:" "${_all_valid_buildOnly}" "ext"
		display_alert "Process aborted" "" "info"
		exit 1
	fi
}

###############################################################################
#
# backward_compatibility_build_only()
#
# This function propagates the deprecated KERNEL_ONLY configuration
# to the appropriate content of the BUILD_ONLY configuration.
# It exists for backward compatibility only.
#
backward_compatibility_build_only() {
	local _kernel_buildOnly="u-boot,kernel,armbian-config,armbian-zsh,plymouth-theme-armbian,armbian-firmware,armbian-bsp"
	# yifengyou: 向前兼容，KERNEL_ONLY已经废弃
	# These checks are necessary for backward compatibility with logic
	# https://github.com/armbian/scripts/tree/master /.github/workflows scripts.
	# They need to be removed when the need disappears there.
	[[ -n $KERNEL_ONLY ]] && {
		display_alert "The KERNEL_ONLY key is no longer used." "KERNEL_ONLY=$KERNEL_ONLY" "wrn"
		if [ "$KERNEL_ONLY" == "no" ]; then
			display_alert "Use an empty BUILD_ONLY variable instead" "" "info"
			[[ -n "${BUILD_ONLY}" ]] && {
				display_alert "A contradiction. BUILD_ONLY contains a goal. Fix it." "${BUILD_ONLY}" "wrn"
				BUILD_ONLY=""
				display_alert "Enforced BUILD_ONLY to an empty string." "" "info"
			}
		elif [ "$KERNEL_ONLY" == "yes" ]; then
			display_alert "Instead, use BUILD_ONLY to select the build target." "$_kernel_buildOnly" "wrn"
			BUILD_ONLY="$_kernel_buildOnly"
			display_alert "BUILD_ONLY enforced to:" "${BUILD_ONLY}" "info"
		fi
	}

	# Validate BUILD_ONLY for valid build task names
	build_validate_buildOnly
}


build_get_boot_sources() {
	if [[ -n $BOOTSOURCE ]]; then
		fetch_from_repo "$BOOTSOURCE" "$BOOTDIR" "$BOOTBRANCH" "yes"
	fi
	if [[ -n $ATFSOURCE ]]; then
		fetch_from_repo "$ATFSOURCE" "$ATFDIR" "$ATFBRANCH" "yes"
	fi
}

build_get_kernel_sources() {
	if [[ -n $KERNELSOURCE ]]; then
		if $(declare -f var_origin_kernel > /dev/null); then
			unset LINUXSOURCEDIR
			LINUXSOURCEDIR="linux-mainline/$KERNEL_VERSION_LEVEL"
			VAR_SHALLOW_ORIGINAL=var_origin_kernel
			waiter_local_git "url=$KERNELSOURCE $KERNELSOURCENAME $KERNELBRANCH dir=$LINUXSOURCEDIR $KERNELSWITCHOBJ"
			unset VAR_SHALLOW_ORIGINAL
		else
			fetch_from_repo "$KERNELSOURCE" "$KERNELDIR" "$KERNELBRANCH" "yes"
		fi
	fi
}

build_uboot() {
	# Don't build at all if the BOOTCONFIG is 'none'.
	[[ "${BOOTCONFIG}" != "none" ]] && {
		# Compile u-boot if packed .deb does not exist or use the one from repository
		if [[ ! -f "${DEB_STORAGE}"/${CHOSEN_UBOOT}_${REVISION}_${ARCH}.deb ]]; then
			if [[ -n "${ATFSOURCE}" && "${REPOSITORY_INSTALL}" != *u-boot* ]]; then
				compile_atf
			fi
			[[ "${REPOSITORY_INSTALL}" != *u-boot* ]] && compile_uboot
		fi
	}
}

build_kernel() {
	# Compile kernel if packed .deb does not exist or use the one from repository
	if [[ ! -f ${DEB_STORAGE}/${CHOSEN_KERNEL}_${REVISION}_${ARCH}.deb ]]; then

		KDEB_CHANGELOG_DIST=$RELEASE
		# yifengyou: 调用 lib/functions/compilation/kernel.sh
		[[ -n $KERNELSOURCE ]] && [[ "${REPOSITORY_INSTALL}" != *kernel* ]] && compile_kernel

	fi
}

build_armbian-config() {
	# Compile armbian-config if packed .deb does not exist or use the one from repository
	if [[ ! -f ${DEB_STORAGE}/armbian-config_${REVISION}_all.deb ]]; then

		[[ "${REPOSITORY_INSTALL}" != *armbian-config* ]] && compile_armbian-config

	fi
}

build_armbian-zsh() {
	# Compile armbian-zsh if packed .deb does not exist or use the one from repository
	if [[ ! -f ${DEB_STORAGE}/armbian-zsh_${REVISION}_all.deb ]]; then

		[[ "${REPOSITORY_INSTALL}" != *armbian-zsh* ]] && compile_armbian-zsh

	fi
}

build_plymouth-theme-armbian() {
	# Compile plymouth-theme-armbian if packed .deb does not exist or use the one from repository
	if [[ ! -f ${DEB_STORAGE}/plymouth-theme-armbian_${REVISION}_all.deb ]]; then

		[[ "${REPOSITORY_INSTALL}" != *plymouth-theme-armbian* ]] && compile_plymouth-theme-armbian

	fi
}

build_armbian-firmware() {
	# Compile armbian-firmware if packed .deb does not exist or use the one from repository
	if ! ls "${DEB_STORAGE}/armbian-firmware_${REVISION}_all.deb" 1> /dev/null 2>&1 || ! ls "${DEB_STORAGE}/armbian-firmware-full_${REVISION}_all.deb" 1> /dev/null 2>&1; then

		if [[ "${REPOSITORY_INSTALL}" != *armbian-firmware* ]]; then
			[[ "${INSTALL_ARMBIAN_FIRMWARE:-yes}" == "yes" ]] && { # Build firmware by default.
				FULL=""
				REPLACE="-full"
				compile_firmware
				FULL="-full"
				REPLACE=""
				compile_firmware
			}

		fi

	fi
}

build_armbian-bsp() {
	# create board support package
	[[ -n "${RELEASE}" && ! -f "${DEB_STORAGE}/${BSP_CLI_PACKAGE_FULLNAME}.deb" && "${REPOSITORY_INSTALL}" != *armbian-bsp-cli* ]] && create_board_package

	# create desktop package
	[[ -n "${RELEASE}" && "${DESKTOP_ENVIRONMENT}" && ! -f "${DEB_STORAGE}/$RELEASE/${CHOSEN_DESKTOP}_${REVISION}_all.deb" && "${REPOSITORY_INSTALL}" != *armbian-desktop* ]] && create_desktop_package
	[[ -n "${RELEASE}" && "${DESKTOP_ENVIRONMENT}" && ! -f "${DEB_STORAGE}/${RELEASE}/${BSP_DESKTOP_PACKAGE_FULLNAME}.deb" && "${REPOSITORY_INSTALL}" != *armbian-bsp-desktop* ]] && create_bsp_desktop_package
}

build_chroot() {
	# build additional packages
	# yifengyou: 构建rootfs
	[[ $EXTERNAL_NEW == compile ]] && chroot_build_packages
}

build_bootstrap() {
	# These two keys are necessary for backward compatibility with logic
	# https://github.com/armbian/scripts/tree/master/.github/workflows scripts.
	# They need to be removed when the need disappears there.
	if [[ $KERNEL_ONLY != yes ]]; then
		# yifengyou: lib/functions/main/rootfs-image.sh
		# yifengyou: 构建image镜像
		[[ $BSP_BUILD != yes ]] && debootstrap_ng
	fi
}

#################################################################################################################################
#
# build_main()
#
# Builds all artifacts or the filtered ones only based on BUILD_ONLY.
# Ensures that any build pre-requisite is met.
#
# BUILD_ONLY: optional comma separated list of artifacts to build only.
#             If this list is empty or not set, then all build tasks will be performed.
#             The following build task names are supported for filtering build tasks:
#               u-boot, kernel, armbian-config, armbian-zsh, plymouth-theme-armbian, armbian-firmware, armbian-bsp, chroot, bootstrap
#
# Note: The list of all valid BUILD_ONLY task names is to be maintained
#       in function build_validate_buildOnly() above as local variable _all_valid_buildOnly.
#
build_main() {
	# yifengyou: 关键函数，开始编译流程

	# yifengyou: 开始编译时间戳
	start=$(date +%s)

	# Check and install dependencies, directory structure and settings
	# The OFFLINE_WORK variable inside the function
	# yifengyou: lib/functions/host/prepare-host.sh
	# yifengyou: 再次检测环境，安装必要依赖
	prepare_host

	# yifengyou: 如果配置了 JUST_INIT ，那么就不会进入真正的编译过程，这里就结束退出了
	[[ "${JUST_INIT}" == "yes" ]] && exit 0

	# yifengyou: 是否删除cache/sources目录
	[[ $CLEAN_LEVEL == *sources* ]] && cleaning "sources"

	# fetch_from_repo <url> <dir> <ref> <subdir_flag>

	# ignore updates help on building all images - for internal purposes
	# yifengyou: IGNORE_UPDATES 脚本中没有其他地方调用，说明这个可以是参数传递
	if [[ $IGNORE_UPDATES != yes ]]; then
		build_task_is_enabled "u-boot" && build_get_boot_sources
		build_task_is_enabled "kernel" && build_get_kernel_sources

		call_extension_method "fetch_sources_tools" <<- 'FETCH_SOURCES_TOOLS'
			*fetch host-side sources needed for tools and build*
			Run early to fetch_from_repo or otherwise obtain sources for needed tools.
		FETCH_SOURCES_TOOLS

		call_extension_method "build_host_tools" <<- 'BUILD_HOST_TOOLS'
			*build needed tools for the build, host-side*
			After sources are fetched, build host-side tools needed for the build.
		BUILD_HOST_TOOLS

		for option in $(tr ',' ' ' <<< "$CLEAN_LEVEL"); do
			[[ $option != sources ]] && cleaning "$option"
		done
	fi

	build_task_is_enabled "u-boot" && build_uboot

	build_task_is_enabled "kernel" && build_kernel

	build_task_is_enabled "armbian-config" && build_armbian-config

	build_task_is_enabled "armbian-zsh" && build_armbian-zsh

	build_task_is_enabled "plymouth-theme-armbian" && build_plymouth-theme-armbian

	build_task_is_enabled "armbian-firmware" && build_armbian-firmware

	overlayfs_wrapper "cleanup"

	build_task_is_enabled "armbian-bsp" && build_armbian-bsp

	# skip image creation if exists. useful for CI when making a lot of images
	# yifengyou: 是否跳过镜像构建阶段，除非设置了参数 IMAGE_PRESENT=yes
	if [ "$IMAGE_PRESENT" == yes ] && ls "${FINALDEST}/${VENDOR}_${REVISION}_${BOARD^}_${RELEASE}_${BRANCH}_${VER/-$LINUXFAMILY/}${DESKTOP_ENVIRONMENT:+_$DESKTOP_ENVIRONMENT}"*.xz 1> /dev/null 2>&1; then
		display_alert "Skipping image creation" "image already made - IMAGE_PRESENT is set" "wrn"
		exit
	fi

	build_task_is_enabled "chroot" && build_chroot

	# yifengyou: 构建img镜像环境
	build_task_is_enabled "bootstrap" && build_bootstrap

	display_alert "Build done" "@host" "info"
	display_alert "Target directory" "${DEB_STORAGE}/" "info"
	build_task_is_enabled "u-boot" && display_alert "U-Boot file name" "${CHOSEN_UBOOT}_${REVISION}_${ARCH}.deb" "info"
	build_task_is_enabled "kernel" && display_alert "Kernel file name" "${CHOSEN_KERNEL}_${REVISION}_${ARCH}.deb" "info"

	call_extension_method "run_after_build" << 'RUN_AFTER_BUILD'
*hook for function to run after build, i.e. to change owner of `$SRC`*
Really one of the last hooks ever called. The build has ended. Congratulations.
- *NOTE:* this will run only if there were no errors during build process.
RUN_AFTER_BUILD

	# yifengyou: 统计编译时间
	end=$(date +%s)
	# yifengyou: start在本函数开头
	runtime_secs=$((end - start))
	# 显示编译时间统计
	display_alert "Runtime" "$(printf "%d:%02d min" $((runtime_secs / 60)) $((runtime_secs % 60)))" "info"

	# yifengyou: 显示编译选项，方便再次使用
	# Make it easy to repeat build by displaying build options used
	[ "$(systemd-detect-virt)" == 'docker' ] && BUILD_CONFIG='docker'
	display_alert "Repeat Build Options" "./compile.sh ${BUILD_CONFIG} BOARD=${BOARD} BRANCH=${BRANCH} \
$([[ -n $RELEASE ]] && echo "RELEASE=${RELEASE} ")\
$([[ -n $BUILD_MINIMAL ]] && echo "BUILD_MINIMAL=${BUILD_MINIMAL} ")\
$([[ -n $BUILD_DESKTOP ]] && echo "BUILD_DESKTOP=${BUILD_DESKTOP} ")\
$([[ -n $BUILD_ONLY ]] && echo "BUILD_ONLY=${BUILD_ONLY} ")\
$([[ -n $KERNEL_ONLY ]] && echo "KERNEL_ONLY=${KERNEL_ONLY} ")\
$([[ -n $KERNEL_CONFIGURE ]] && echo "KERNEL_CONFIGURE=${KERNEL_CONFIGURE} ")\
$([[ -n $DESKTOP_ENVIRONMENT ]] && echo "DESKTOP_ENVIRONMENT=${DESKTOP_ENVIRONMENT} ")\
$([[ -n $DESKTOP_ENVIRONMENT_CONFIG_NAME ]] && echo "DESKTOP_ENVIRONMENT_CONFIG_NAME=${DESKTOP_ENVIRONMENT_CONFIG_NAME} ")\
$([[ -n $DESKTOP_APPGROUPS_SELECTED ]] && echo "DESKTOP_APPGROUPS_SELECTED=\"${DESKTOP_APPGROUPS_SELECTED}\" ")\
$([[ -n $DESKTOP_APT_FLAGS_SELECTED ]] && echo "DESKTOP_APT_FLAGS_SELECTED=\"${DESKTOP_APT_FLAGS_SELECTED}\" ")\
$([[ -n $COMPRESS_OUTPUTIMAGE ]] && echo "COMPRESS_OUTPUTIMAGE=${COMPRESS_OUTPUTIMAGE} ")\
" "ext"
	# yifengyou: hook docker build exit
	if [ -f /.dockerenv ] ; then
		echo "yifengyou: Finished build. Enter bash shell"
		cd /root/armbian
		exec /bin/bash
	fi
}

################################################################
#
# do_default()
#
# @DEPRECATED - use build_main() instead.
# This function is still there for backward compatibility only.
#
# yifengyou： 这个函数没有其他地方调用，但是为了兼容保留
do_default() {
	build_main
}
