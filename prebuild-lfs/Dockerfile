FROM ubuntu:22.04
MAINTAINER Ron Hatch <ronhatch@earthlink.net>
ENV LFS=/lfs
ENV LC_ALL=POSIX
ENV PATH=$LFS/tools/bin:/usr/sbin:/usr/bin
ENV LFS_TGT=x86_64-lfs-linux-gnu
ENV CONFIG_SITE=$LFS/usr/share/config.site
RUN rm -f /bin/sh; \
    ln -s /usr/bin/bash /bin/sh; \
    groupadd --gid 1000 lfs; \
    useradd --uid 1000 -s /bin/bash -g lfs -m -k /dev/null lfs; \
    mkdir -p $LFS/etc $LFS/lib64 $LFS/sources $LFS/tools $LFS/var \
             $LFS/usr/bin $LFS/usr/lib $LFS/usr/sbin; \
    ln -s usr/bin $LFS/bin; \
    ln -s usr/lib $LFS/lib; \
    ln -s usr/sbin $LFS/sbin; \
    chown lfs:lfs -R $LFS; \
    chmod a+wt $LFS/sources; \
    apt update && \
    apt -y install binutils bison gawk gcc g++ make patch perl python3 texinfo xz-utils
USER lfs
WORKDIR /home/lfs
