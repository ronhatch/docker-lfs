FROM ubuntu:22.04 AS prebuild
MAINTAINER Ron Hatch <ronhatch@earthlink.net>
ENV LFS=/lfs
ENV LC_ALL=POSIX
ENV PATH=$LFS/tools/bin:/usr/sbin:/usr/bin
ENV LFS_TGT=x86_64-lfs-linux-gnu
ENV CONFIG_SITE=$LFS/usr/share/config.site
RUN rm -f /bin/sh; \
    ln -sv /usr/bin/bash /bin/sh; \
    groupadd --gid 1000 lfs; \
    useradd --uid 1000 -s /bin/bash -g lfs -m -k /dev/null lfs; \
    mkdir -pv $LFS/etc $LFS/lib64 $LFS/sources $LFS/tools $LFS/var \
             $LFS/usr/bin $LFS/usr/lib $LFS/usr/sbin; \
    ln -sv usr/bin $LFS/bin; \
    ln -sv usr/lib $LFS/lib; \
    ln -sv usr/sbin $LFS/sbin; \
    chown lfs:lfs -R $LFS; \
    chmod a+wt $LFS/sources; \
    apt update && \
    apt -y install binutils bison gawk gcc g++ make patch perl python3 texinfo xz-utils
USER lfs
WORKDIR /home/lfs

FROM prebuild AS binutils-1
MAINTAINER Ron Hatch <ronhatch@earthlink.net>
ADD --chown=lfs https://ftp.gnu.org/gnu/binutils/binutils-2.39.tar.xz $LFS/sources
RUN pushd $LFS/sources; \
    tar xf binutils-2.39.tar.xz; \
    mkdir -v binutils-2.39/build; \
    cd binutils-2.39/build; \
    ../configure --prefix=$LFS/tools --with-sysroot=$LFS \
        --target=$LFS_TGT --disable-nls \
        --enable-gprofng=no --disable-werror && \
    make && make install; \
    popd; \
    rm -rf $LFS/sources/binutils-2.39*
