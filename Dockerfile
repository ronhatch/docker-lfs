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

# --- M4: Chapter 6.2 ---
FROM prebuild AS m4
COPY --from=libstdc $LFS $LFS
ADD --chown=lfs https://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.xz $LFS_SRC
RUN cd $LFS_SRC; \
    tar xf m4-1.4.19.tar.xz
RUN cd $LFS_SRC/m4-1.4.19; \
    ./configure --prefix=/usr --host=$LFS_TGT \ 
        --build=$(build-aux/config.guess) && \
    make && make DESTDIR=$LFS install

# --- Ncurses: Chapter 6.3 ---
FROM prebuild AS ncurses
COPY --from=m4 $LFS $LFS
ADD --chown=lfs https://invisible-mirror.net/archives/ncurses/ncurses-6.3.tar.gz $LFS_SRC
RUN cd $LFS_SRC; \
    tar xf ncurses-6.3.tar.gz; \
    sed -i s/mawk// ncurses-6.3/configure; \
    mkdir -v ncurses-6.3/build; \
    cd ncurses-6.3/build; \
    ../configure && \
    make -C include && \
    make -C progs tic
RUN cd $LFS_SRC/ncurses-6.3; \
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess) \
        --mandir=/usr/share/man --with-manpage-format=normal \
        --with-shared --without-normal --with-cxx-shared --without-debug \
        --without-ada --disable-stripping --enable-widec && \
    make && make DESTDIR=$LFS TIC_PATH=$(pwd)/build/progs/tic install && \
    echo "INPUT(-lncursesw)" > $LFS/usr/lib/libncurses.so

# --- Bash: Chapter 6.4 ---
FROM prebuild AS bash
COPY --from=ncurses $LFS $LFS
ADD --chown=lfs https://ftp.gnu.org/gnu/bash/bash-5.1.16.tar.gz $LFS_SRC
RUN cd $LFS_SRC; \
    tar xf bash-5.1.16.tar.gz
RUN cd $LFS_SRC/bash-5.1.16; \
    ./configure --prefix=/usr --build=$(support/config.guess) \
        --host=$LFS_TGT --without-bash-malloc && \
    make && make DESTDIR=$LFS install && \
    ln -sv bash $LFS/bin/sh

# --- Coreutils: Chapter 6.5 ---
FROM prebuild AS coreutils
COPY --from=bash $LFS $LFS
ADD --chown=lfs https://ftp.gnu.org/gnu/coreutils/coreutils-9.1.tar.xz $LFS_SRC
RUN cd $LFS_SRC; \
    tar xf coreutils-9.1.tar.xz
RUN cd $LFS_SRC/coreutils-9.1; \
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess) \
        --enable-install-program=hostname --enable-no-install-program=kill,uptime && \
    make && make DESTDIR=$LFS install; \
    mv -v $LFS/usr/{bin/chroot,sbin}; \
    mkdir -pv $LFS/usr/share/man/man8; \
    mv -v $LFS/usr/share/man/{man1/chroot.1,man8/chroot.8}; \
    sed -i 's/"1"/"8"/' $LFS/usr/share/man/man8/chroot.8

# --- Diffutils: Chapter 6.6 ---
FROM prebuild AS diffutils
COPY --from=coreutils $LFS $LFS
ADD --chown=lfs https://ftp.gnu.org/gnu/diffutils/diffutils-3.8.tar.xz $LFS_SRC
RUN cd $LFS_SRC; \
    tar xf diffutils-3.8.tar.xz
RUN cd $LFS_SRC/diffutils-3.8; \
    ./configure --prefix=/usr --host=$LFS_TGT && \
    make && make DESTDIR=$LFS install

# --- File: Chapter 6.7 ---
FROM prebuild AS file
COPY --from=diffutils $LFS $LFS
ADD --chown=lfs https://astron.com/pub/file/file-5.42.tar.gz $LFS_SRC
RUN cd $LFS_SRC; \
    tar xf file-5.42.tar.gz; \
    mkdir -v file-5.42/build
RUN cd $LFS_SRC/file-5.42/build; \
    ../configure --disable-bzlib --disable-libseccomp \
        --disable-xzlib --disable-zlib && \
    make
RUN cd $LFS_SRC/file-5.42; \
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess) && \
    make FILE_COMPILE=$(pwd)/build/src/file && \
    make DESTDIR=$LFS install && \
    rm -v $LFS/usr/lib/libmagic.la

# --- Findutils: Chapter 6.8 ---
FROM prebuild AS findutils
COPY --from=file $LFS $LFS
ADD --chown=lfs https://ftp.gnu.org/gnu/findutils/findutils-4.9.0.tar.xz $LFS_SRC
RUN cd $LFS_SRC; \
    tar xf findutils-4.9.0.tar.xz
RUN cd $LFS_SRC/findutils-4.9.0; \
    ./configure --prefix=/usr --localstatedir=/var/lib/locate \
        --host=$LFS_TGT --build=$(build-aux/config.guess) && \
    make && make DESTDIR=$LFS install

# --- Gawk: Chapter 6.9 ---
FROM prebuild AS gawk
COPY --from=findutils $LFS $LFS
ADD --chown=lfs https://ftp.gnu.org/gnu/gawk/gawk-5.1.1.tar.xz $LFS_SRC
RUN cd $LFS_SRC; \
    tar xf gawk-5.1.1.tar.xz; \
    sed -i 's/extras//' gawk-5.1.1/Makefile.in
RUN cd $LFS_SRC/gawk-5.1.1; \
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess) && \
    make && make DESTDIR=$LFS install

# --- Grep: Chapter 6.10 ---
FROM prebuild AS grep
COPY --from=gawk $LFS $LFS
ADD --chown=lfs https://ftp.gnu.org/gnu/grep/grep-3.7.tar.xz $LFS_SRC
RUN cd $LFS_SRC; \
    tar xf grep-3.7.tar.xz
RUN cd $LFS_SRC/grep-3.7; \
    ./configure --prefix=/usr --host=$LFS_TGT && \
    make && make DESTDIR=$LFS install

# --- Gzip: Chapter 6.11 ---
FROM prebuild AS gzip
COPY --from=grep $LFS $LFS
ADD --chown=lfs https://ftp.gnu.org/gnu/gzip/gzip-1.12.tar.xz $LFS_SRC
RUN cd $LFS_SRC; \
    tar xf gzip-1.12.tar.xz
RUN cd $LFS_SRC/gzip-1.12; \
    ./configure --prefix=/usr --host=$LFS_TGT && \
    make && make DESTDIR=$LFS install

# --- Make: Chapter 6.12 ---
FROM prebuild AS make
COPY --from=gzip $LFS $LFS
ADD --chown=lfs https://ftp.gnu.org/gnu/make/make-4.3.tar.gz $LFS_SRC
RUN cd $LFS_SRC; \
    tar xf make-4.3.tar.gz
RUN cd $LFS_SRC/make-4.3; \
    ./configure --prefix=/usr --without-guile --host=$LFS_TGT \
        --build=$(build-aux/config.guess) && \
    make && make DESTDIR=$LFS install

# --- Patch: Chapter 6.13 ---
FROM prebuild AS patch
COPY --from=make $LFS $LFS
ADD --chown=lfs https://ftp.gnu.org/gnu/patch/patch-2.7.6.tar.xz $LFS_SRC
RUN cd $LFS_SRC; \
    tar xf patch-2.7.6.tar.xz
RUN cd $LFS_SRC/patch-2.7.6; \
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess) && \
    make && make DESTDIR=$LFS install

# --- Sed: Chapter 6.14 ---
FROM prebuild AS sed
COPY --from=patch $LFS $LFS
ADD --chown=lfs https://ftp.gnu.org/gnu/sed/sed-4.8.tar.xz $LFS_SRC
RUN cd $LFS_SRC; \
    tar xf sed-4.8.tar.xz
RUN cd $LFS_SRC/sed-4.8; \
    ./configure --prefix=/usr --host=$LFS_TGT && \
    make && make DESTDIR=$LFS install

# --- Tar: Chapter 6.15 ---
FROM prebuild AS tar
COPY --from=sed $LFS $LFS
ADD --chown=lfs https://ftp.gnu.org/gnu/tar/tar-1.34.tar.xz $LFS_SRC
RUN cd $LFS_SRC; \
    tar xf tar-1.34.tar.xz
RUN cd $LFS_SRC/tar-1.34; \
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess) && \
    make && make DESTDIR=$LFS install

# --- Xz: Chapter 6.16 ---
FROM prebuild AS xz
COPY --from=tar $LFS $LFS
# Note: Official download link listed in LFS book was resulting in errors.
#       Using sourceforge instead, but not sure if this is a permanent link.
ADD --chown=lfs https://pilotfiber.dl.sourceforge.net/project/lzmautils/xz-5.2.6.tar.xz $LFS_SRC
RUN cd $LFS_SRC; \
    tar xf xz-5.2.6.tar.xz
RUN cd $LFS_SRC/xz-5.2.6; \
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess) \
        --disable-static --docdir=/usr/share/doc/xz-5.2.6 && \
    make && make DESTDIR=$LFS install && \
    rm -v $LFS/usr/lib/liblzma.la

# --- Binutils 2nd pass: Chapter 6.17 ---
FROM prebuild AS binutils-2
COPY --from=xz $LFS $LFS
ADD --chown=lfs https://ftp.gnu.org/gnu/binutils/binutils-2.39.tar.xz $LFS_SRC
RUN cd $LFS_SRC; \
    tar xf binutils-2.39.tar.xz; \
    sed '6009s/$add_dir//' -i ltmain.sh; \
    mkdir -v binutils-2.39/build
RUN cd $LFS_SRC/binutils-2.39/build; \
    ../configure --prefix=/usr --build=$(../config.guess) --host=$LFS_TGT \
        --disable-nls --enable-shared --enable-gprofng=no \
        --disable-werror --enable-64-bit-bfd && \
    make && make DESTDIR=$LFS install && \
    rm -v $LFS/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes}.{a,la}

# --- GCC 2nd pass: Chapter 6.18 ---
FROM prebuild AS gcc-2
COPY --from=binutils-2 $LFS $LFS
ADD --chown=lfs https://ftp.gnu.org/gnu/gcc/gcc-12.2.0/gcc-12.2.0.tar.xz $LFS_SRC
ADD --chown=lfs https://ftp.gnu.org/gnu/gmp/gmp-6.2.1.tar.xz $LFS_SRC
ADD --chown=lfs https://ftp.gnu.org/gnu/mpc/mpc-1.2.1.tar.gz $LFS_SRC
ADD --chown=lfs https://ftp.gnu.org/gnu/mpfr/mpfr-4.1.0.tar.xz $LFS_SRC
RUN cd $LFS_SRC; \
    tar xf gcc-12.2.0.tar.xz; \
    cd gcc-12.2.0; \
    tar xf ../gmp-6.2.1.tar.xz; \
    mv -v gmp-6.2.1 gmp; \
    tar xf ../mpc-1.2.1.tar.gz; \
    mv -v mpc-1.2.1 mpc; \
    tar xf ../mpfr-4.1.0.tar.xz; \
    mv -v mpfr-4.1.0 mpfr; \
    sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64; \
    sed '/thread_header =/s/@.*@/gthr-posix.h/' \
        -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in; \
    mkdir -v build
RUN cd $LFS_SRC/gcc-12.2.0/build; \
    ../configure --build=$(../config.guess) --host=$LFS_TGT --target=$LFS_TGT \
        LDFLAGS_FOR_TARGET=-L$PWD/$LFS_TGT/libgcc --prefix=/usr \
        --with-build-sysroot=$LFS --enable-initfini-array --disable-nls \
        --disable-multilib --disable-decimal-float --disable-libatomic \
        --disable-libgomp --disable-libquadmath --disable-libssp \
        --disable-libvtv --enable-languages=c,c++ && \
    make && make DESTDIR=$LFS install && \
    ln -sv gcc $LFS/usr/bin/cc
