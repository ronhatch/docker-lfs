FROM ubuntu:22.04
MAINTAINER Ron Hatch <ronhatch@earthlink.net>
RUN rm -f /bin/sh; ln -s /usr/bin/bash /bin/sh; groupadd --gid 1000 lfs; useradd --uid 1000 -s /bin/bash -g lfs -m -k /dev/null lfs; apt update && apt -y install binutils bison gawk gcc g++ make patch perl python3 texinfo xz-utils
USER lfs
WORKDIR /home/lfs
