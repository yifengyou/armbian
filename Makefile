.PHONY: default docker-shell current edge

default:
	@echo "docker-shell               run docker shell"
	@echo "current                    build current with edidk-610 kernel 5"
	@echo "edge                       build edge with edidk-610 kernel 6"

docker-shell:
	./compile.sh docker-shell

current:
	./compile.sh docker \
        BOARD=eaidk-610 \
        BRANCH=current \
        RELEASE=jammy \
        BUILD_MINIMAL=no \
        BUILD_DESKTOP=no \
        KERNEL_CONFIGURE=no \
        COMPRESS_OUTPUTIMAGE=sha,gpg,img | tee log.eaidk610-kernel5

edge:
	./compile.sh docker \
        BOARD=eaidk-610 \
        BRANCH=edge \
        RELEASE=jammy \
        BUILD_MINIMAL=no \
        BUILD_DESKTOP=yes \
        DESKTOP_ENVIRONMENT=gnome \
        DESKTOP_ENVIRONMENT_CONFIG_NAME="config_full" \
        DESKTOP_APPGROUPS_SELECTED="browsers" \
        KERNEL_CONFIGURE=no \
        COMPRESS_OUTPUTIMAGE=sha,gpg,img | tee log.eaidk610-kernel6


status:
	docker ps -a
