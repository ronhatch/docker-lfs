# --- Prebuild environment: Chapters 1-4 ---
FROM ubuntu:22.04 AS prebuild
LABEL maintainer="Ron Hatch <ronhatch@earthlink.net>"
ENV LFS=/lfs
ENV LFS_SRC=/home/lfs/sources
ENV LC_ALL=POSIX
ENV PATH=$LFS/tools/bin:/usr/sbin:/usr/bin
ENV LFS_TGT=x86_64-lfs-linux-gnu
ENV CONFIG_SITE=$LFS/usr/share/config.site
SHELL ["/bin/bash", "--login", "-c"]
RUN rm -f /bin/sh; \
    ln -sv /usr/bin/bash /bin/sh; \
    groupadd --gid 1000 lfs; \
    useradd --uid 1000 -s /bin/bash -g lfs -m -k /dev/null lfs; \
    mkdir -pv $LFS/{etc,lib64,tools,var} $LFS/usr/{bin,lib,sbin}; \
    for i in bin lib sbin; do ln -sv usr/$i $LFS/$i; done; \
    mkdir -pv $LFS_SRC; \
    chown lfs:lfs -R $LFS $LFS_SRC; \
    chmod a+wt $LFS_SRC; \
    apt update && \
    apt -y install binutils bison gawk gcc g++ make patch perl python3 texinfo xz-utils
COPY scripts/version-check.sh /home/lfs
COPY scripts/bashrc /home/lfs/.bashrc
USER lfs
WORKDIR /home/lfs

# --- Binutils 1st pass: Chapter 5.2 ---
FROM prebuild AS binutils-1
ADD --chown=lfs https://ftp.gnu.org/gnu/binutils/binutils-2.39.tar.xz $LFS_SRC
RUN cd $LFS_SRC; \
    tar xf binutils-2.39.tar.xz; \
    mkdir -v binutils-2.39/build
RUN cd $LFS_SRC/binutils-2.39/build; \
    ../configure --prefix=$LFS/tools --with-sysroot=$LFS \
        --target=$LFS_TGT --disable-nls \
        --enable-gprofng=no --disable-werror && \
    make && make install

