#!/usr/bin/env bash

# yifengyou: compile.sh 跳转到这里执行
function cli_entrypoint() {
	if [[ "${ARMBIAN_ENABLE_CALL_TRACING}" == "yes" ]]; then
	  # -T  If set, the DEBUG and RETURN traps are inherited by shell functions.
		set -T # inherit return/debug traps
		mkdir -p "${SRC}"/output/debug
		echo -n "" > "${SRC}"/output/debug/calls.txt
		trap 'echo "${BASH_LINENO[@]}|${BASH_SOURCE[@]}|${FUNCNAME[@]}" >> ${SRC}/output/debug/calls.txt ;' RETURN
	fi

	# yifengyou: lib/functions/cli/utils-cli.sh
	# yifengyou: check_args BOARD=eaidk-610 BRANCH=edge RELEASE=jammy BUILD_MINIMAL=no BUILD_DESKTOP=no
	#                         KERNEL_CONFIGURE=no COMPRESS_OUTPUTIMAGE=sha,gpg,img
	check_args "$@"

	# yifengyou: lib/functions/cli/utils-cli.sh
	# 检查是否为虚拟环境，不是虚拟环境会检查.git和暂存区的内容是否要提交
	do_update_src

  # 要求root权限
	if [[ "${EUID}" == "0" ]] || [[ "${1}" == "vagrant" ]]; then
		:
	elif [[ "${1}" == docker || "${1}" == dockerpurge || "${1}" == docker-shell ]] && grep -q "$(whoami)" <(getent group docker); then
		:
	else
		display_alert "This script requires root privileges, trying to use sudo" "" "wrn"
		sudo "${SRC}/compile.sh" "$@"
		exit $?
	fi

	if [ "$OFFLINE_WORK" == "yes" ]; then
		# yifengyou: 离线模式，少了哪些事情？该下载的包一个都不能少，到底哪里离线了？
		echo -e "\n"
		display_alert "* " "You are working offline."
		display_alert "* " "Sources, time and host will not be checked"
		echo -e "\n"
		sleep 3s

	else

		# check and install the basic utilities here
		# yifengyou: lib/functions/host/basic-deps.sh
		# 安装所需依赖包，OFFLINE_WORK=“yes" 就会跳过安装
		prepare_host_basic

	fi

	# yifengyou: Vagrant 是一个基于 Ruby 的工具，用于创建和部署虚拟化开发环境
	# lib/functions/cli/utils-cli.sh
	handle_vagrant "$@"

	# Purge Armbian Docker images
	# ./compile.sh docker BOARD=eaidk-610 BRANCH=edge RELEASE=jammy
	# 			BUILD_MINIMAL=no BUILD_DESKTOP=no KERNEL_CONFIGURE=no COMPRESS_OUTPUTIMAGE=sha,gpg,img
	# yifengyou: 清理armbian docker构建镜像后重新制作
	if [[ "${1}" == dockerpurge && -f /etc/debian_version ]]; then
		display_alert "Purging Armbian Docker containers" "" "wrn"
		# 清理armbian容器
		docker container ls -a | grep armbian | awk '{print $1}' | xargs docker container rm &> /dev/null
		# 清理armbian镜像，重新构建image
		docker image ls | grep armbian | awk '{print $3}' | xargs docker image rm &> /dev/null
		# yifengyou: 移除dockerpurge命令
		shift
		# yifengyou: 移除dockerpurge后添加docker命令，set -- 用法，可以调整脚本参数
		set -- "docker" "$@"
	fi

	# Docker shell
	if [[ "${1}" == docker-shell ]]; then
		shift
		#shellcheck disable=SC2034
		SHELL_ONLY=yes
		# ./compile.sh docker-shell
		# yifengyou: 这个命令很管用，可以进armbian docker构建环境调试
		set -- "docker" "$@"
	fi

  # 检查docker环境
  # yifengyou: lib/functions/cli/utils-cli.sh
  # 如果指定docker编译，检查docker命令是否存在，不存在安装，并重新执行命令
	handle_docker "$@"

	# yifengyou: lib/functions/cli/utils-cli.sh
	# 创建userpatches目录，软链配置
	prepare_userpatches

	# yifengyou: 我的参数指定docker，则默认读取 userpatches/config-docker.conf
	# 这个配置是从 config/templates/config-docker.conf 拷贝过去的
	# ./compile.sh docker BOARD=eaidk-610 BRANCH=edge RELEASE=jammy
	# 			BUILD_MINIMAL=no BUILD_DESKTOP=no KERNEL_CONFIGURE=no COMPRESS_OUTPUTIMAGE=sha,gpg,img
	if [[ -z "${CONFIG}" && -n "$1" && -f "${SRC}/userpatches/config-$1.conf" ]]; then
		CONFIG="userpatches/config-$1.conf"
		# 移除docker参数
		shift
	fi

	# usind default if custom not found
	if [[ -z "${CONFIG}" && -f "${SRC}/userpatches/config-default.conf" ]]; then
		CONFIG="userpatches/config-default.conf"
	fi

	# source build configuration file
	CONFIG_FILE="$(realpath "${CONFIG}")"

	if [[ ! -f "${CONFIG_FILE}" ]]; then
		display_alert "Config file does not exist" "${CONFIG}" "error"
		exit 254
	fi

	# yifengyou: 咱的参数 CONFIG_PATH=userpatches
	# ./compile.sh docker BOARD=eaidk-610 BRANCH=edge RELEASE=jammy
	# 			BUILD_MINIMAL=no BUILD_DESKTOP=no KERNEL_CONFIGURE=no COMPRESS_OUTPUTIMAGE=sha,gpg,img
	CONFIG_PATH=$(dirname "${CONFIG_FILE}")

	# Source the extensions manager library at this point, before sourcing the config.
	# This allows early calls to enable_extension(), but initialization proper is done later.
	# shellcheck source=lib/extensions.sh
	# yifengyou； 加载变量、扩展函数
	source "${SRC}"/lib/extensions.sh

	display_alert "Using config file" "${CONFIG_FILE}" "info"
	# yifengyou: config其实也是shell可识别的配置
	pushd "${CONFIG_PATH}" > /dev/null || exit
	# shellcheck source=/dev/null
	source "${CONFIG_FILE}"
	popd > /dev/null || exit

	# yifengyou: 如果没有指定userpatches的路径，那么跟CONFIG_PATH保持一致
	[[ -z "${USERPATCHES_PATH}" ]] && USERPATCHES_PATH="${CONFIG_PATH}"

	# yifengyou: 我的参数，docker被shift了，剩下其他参数，都会被键值对提取
	# ./compile.sh docker BOARD=eaidk-610 BRANCH=edge RELEASE=jammy
	# 			BUILD_MINIMAL=no BUILD_DESKTOP=no KERNEL_CONFIGURE=no COMPRESS_OUTPUTIMAGE=sha,gpg,img
	# Script parameters handling
	while [[ "${1}" == *=* ]]; do

		parameter=${1%%=*}
		value=${1##*=}
		shift
		display_alert "Command line: setting $parameter to" "${value:-(empty)}" "info"
		eval "$parameter=\"$value\""

	done

	# yifengyou: lib/functions/main/config-prepare.sh
	# 关键点：日志备份、信息搜集，获取必要参数，准备开始编译。相当于原材料准备
	prepare_and_config_main_build_single

	if [[ -z $1 ]]; then
		build_main
	else
		eval "$@"
	fi
}
