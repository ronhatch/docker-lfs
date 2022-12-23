FROM ubuntu:22.04
MAINTAINER Ron Hatch <ronhatch@earthlink.net>
RUN rm -f /bin/sh; ln -s /usr/bin/bash /bin/sh; groupadd --gid 1000 lfs; useradd --uid 1000 -s /bin/bash -g lfs -m -k /dev/null lfs; mkdir -pv $LFS/{etc,lib64,tools,var} $LFS/usr/{bin,lib,sbin}; ln -sv usr/bin $LFS/bin; ln -sv usr/lib $LFS/lib; ln -sv usr/sbin $LFS/sbin; chown lfs:lfs -R $LFS; apt update && apt -y install binutils bison gawk gcc g++ make patch perl python3 texinfo xz-utils
USER lfs
WORKDIR /home/lfs
