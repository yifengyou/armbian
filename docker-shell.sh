#!/bin/bash

set -x

rm -f userpatches/config-docker.conf
./compile.sh docker-shell

#docker run -it --name armbian -v /data:/data --entrypoint /bin/bash 929

