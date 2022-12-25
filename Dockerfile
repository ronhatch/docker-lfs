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

# --- GCC 1st pass: Chapter 5.3 ---
FROM prebuild AS gcc-1
COPY --from=binutils-1 $LFS $LFS
ADD --chown=lfs https://ftp.gnu.org/gnu/gcc/gcc-12.2.0/gcc-12.2.0.tar.xz $LFS_SRC
ADD --chown=lfs https://ftp.gnu.org/gnu/gmp/gmp-6.2.1.tar.xz $LFS_SRC
ADD --chown=lfs https://ftp.gnu.org/gnu/mpc/mpc-1.2.1.tar.gz $LFS_SRC
ADD --chown=lfs https://ftp.gnu.org/gnu/mpfr/mpfr-4.1.0.tar.xz $LFS_SRC
RUN cd $LFS_SRC; \
    tar xf gcc-12.2.0.tar.xz; \
    cd gcc-12.2.0; \
    tar xf ../gmp-6.2.1.tar.xz; \
    mv gmp-6.2.1 gmp; \
    tar xf ../mpc-1.2.1.tar.gz; \
    mv mpc-1.2.1 mpc; \
    tar xf ../mpfr-4.1.0.tar.xz; \
    mv mpfr-4.1.0 mpfr; \
    sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64; \
    mkdir -v build
RUN cd $LFS_SRC/gcc-12.2.0/build; \
    ../configure --target=$LFS_TGT --prefix=$LFS/tools --with-glibc-version=2.36 \
        --with-sysroot=$LFS --with-newlib --without-headers --disable-nls \
        --disable-shared --disable-multilib --disable-decimal-float \
        --disable-threads --disable-libatomic --disable-libgomp \
        --disable-libquadmath --disable-libssp --disable-libvtv \
        --disable-libstdcxx --enable-languages=c,c++ && \
    make && make install && \
    cd .. && cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
        `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/install-tools/include/limits.h

# --- Linux API headers: Chapter 5.4 ---
FROM prebuild AS linux-headers
COPY --from=gcc-1 $LFS $LFS
ADD --chown=lfs https://www.kernel.org/pub/linux/kernel/v6.x/linux-6.0.11.tar.xz $LFS_SRC
RUN cd $LFS_SRC; \
    tar xf linux-6.0.11.tar.xz
RUN cd $LFS_SRC/linux-6.0.11; \
    make mrproper && make headers && \
    find usr/include -type f ! -name '*.h' -delete && \
    cp -rv usr/include $LFS/usr

# --- Glibc: Chapter 5.5 ---
FROM prebuild AS glibc
COPY --from=linux-headers $LFS $LFS
ADD --chown=lfs https://ftp.gnu.org/gnu/glibc/glibc-2.36.tar.xz $LFS_SRC
ADD --chown=lfs https://www.linuxfromscratch.org/patches/lfs/11.2/glibc-2.36-fhs-1.patch $LFS_SRC
RUN cd $LFS_SRC; \
    tar xf glibc-2.36.tar.xz; \
    cd glibc-2.36; \
    ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64; \
    ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3; \
    patch -Np1 -i ../glibc-2.36-fhs-1.patch; \
    mkdir -v build
RUN cd $LFS_SRC/glibc-2.36/build; \
    echo "rootsbindir=/usr/sbin" > configparms; \
    ../configure --prefix=/usr --host=$LFS_TGT \
        --build=$(../scripts/config.guess) --enable-kernel=3.2 \
        --with-headers=$LFS/usr/include libc_cv_slibdir=/usr/lib && \
    make && make DESTDIR=$LFS install && \
    sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd && \
    $LFS/tools/libexec/gcc/$LFS_TGT/12.2.0/install-tools/mkheaders

# --- Libstdc++: Chapter 5.6 ---
FROM prebuild AS libstdc
COPY --from=glibc $LFS $LFS
ADD --chown=lfs https://ftp.gnu.org/gnu/gcc/gcc-12.2.0/gcc-12.2.0.tar.xz $LFS_SRC
RUN cd $LFS_SRC; \
    tar xf gcc-12.2.0.tar.xz; \
    mkdir -v gcc-12.2.0/build
RUN cd $LFS_SRC/gcc-12.2.0/build; \
    ../libstdc++-v3/configure --host=$LFS_TGT --build=$(../config.guess) \
        --prefix=/usr --disable-multilib --disable-nls --disable-libstdcxx-pch \
        --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/12.2.0 && \
    make && make DESTDIR=$LFS install; \
    rm -v $LFS/usr/lib/lib{stdc++,stdc++fs,supc++}.la

# Eventually, we'll run:
#FROM scratch
#COPY --from=last-stage $LFS /
