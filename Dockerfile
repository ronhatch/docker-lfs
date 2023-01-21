# syntax=docker/dockerfile:1
# Use BuildKit, needed for the heredoc feature.

# --- Prebuild environment: Chapters 1-4 ---
FROM ubuntu:22.04 AS prebuild
LABEL maintainer="Ron Hatch <ronhatch@earthlink.net>"
ENV LFS=/lfs
ENV LFS_SRC=/root/sources
ENV LC_ALL=POSIX
ENV PATH=$LFS/tools/bin:/usr/sbin:/usr/bin
ENV LFS_TGT=x86_64-lfs-linux-gnu
ENV CONFIG_SITE=$LFS/usr/share/config.site
SHELL ["/bin/bash", "+h", "-c"]
RUN <<CMD_LIST
    rm -f /bin/sh
    ln -sv /usr/bin/bash /bin/sh
    mkdir -pv $LFS/{etc,lib64,tools,var} $LFS/usr/{bin,lib,sbin}
    for i in bin lib sbin; do
      ln -sv usr/$i $LFS/$is
    done
    mkdir -pv $LFS_SRC
    apt update
    apt -y install binutils bison gawk gcc g++ make patch perl python3 texinfo xz-utils
CMD_LIST
COPY scripts/version-check.sh /root
WORKDIR /root

# --- Binutils 1st pass: Chapter 5.2 ---
# In this and all later steps, the src postfix is used for source tarball
#   unpacked only (image is suitable for examining for possible patches).
#   The bld postfix is used after the package is built but before it is
#   installed (image is suitable for running test suites).
FROM prebuild AS binutils1-src
ADD sources/binutils-2.39.tar.xz $LFS_SRC
RUN mkdir -v $LFS_SRC/binutils-2.39/build
WORKDIR $LFS_SRC/binutils-2.39/build

FROM binutils1-src AS binutils1-bld
RUN <<CMD_LIST
    ../configure --prefix=$LFS/tools --with-sysroot=$LFS \
        --target=$LFS_TGT --disable-nls \
        --enable-gprofng=no --disable-werror
    make
CMD_LIST

FROM binutils1-bld AS binutils1
RUN make install

# --- GCC 1st pass: Chapter 5.3 ---
FROM prebuild AS gcc1-src
COPY --from=binutils1 $LFS $LFS
ADD sources/gcc-12.2.0.tar.xz $LFS_SRC
ADD sources/gmp-6.2.1.tar.xz $LFS_SRC/gcc-12.2.0
ADD sources/mpc-1.2.1.tar.gz $LFS_SRC/gcc-12.2.0
ADD sources/mpfr-4.1.0.tar.xz $LFS_SRC/gcc-12.2.0
RUN <<CMD_LIST
    cd $LFS_SRC/gcc-12.2.0
    mv gmp-6.2.1 gmp
    mv mpc-1.2.1 mpc
    mv mpfr-4.1.0 mpfr
    sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
    mkdir -v build
CMD_LIST
WORKDIR $LFS_SRC/gcc-12.2.0/build

FROM gcc1-src AS gcc1-bld
RUN <<CMD_LIST
    ../configure --target=$LFS_TGT --prefix=$LFS/tools --with-glibc-version=2.36 \
        --with-sysroot=$LFS --with-newlib --without-headers --disable-nls \
        --disable-shared --disable-multilib --disable-decimal-float \
        --disable-threads --disable-libatomic --disable-libgomp \
        --disable-libquadmath --disable-libssp --disable-libvtv \
        --disable-libstdcxx --enable-languages=c,c++
    make
CMD_LIST

FROM gcc1-bld AS gcc1
RUN <<CMD_LIST
    make install
    cd ..
    cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
        `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/install-tools/include/limits.h
CMD_LIST

# --- Linux API headers: Chapter 5.4 ---
FROM prebuild AS headers-src
COPY --from=gcc1 $LFS $LFS
ADD sources/linux-6.0.11.tar.xz $LFS_SRC
WORKDIR $LFS_SRC/linux-6.0.11

FROM headers-src AS headers-bld
RUN <<CMD_LIST
    make mrproper
    make headers
    find usr/include -type f ! -name '*.h' -delete
CMD_LIST

FROM headers-bld AS headers
RUN cp -rv usr/include $LFS/usr

# --- Glibc: Chapter 5.5 ---
FROM prebuild AS glibc-src
COPY --from=headers $LFS $LFS
ADD sources/glibc-2.36.tar.xz $LFS_SRC
ADD sources/glibc-2.36-fhs-1.patch $LFS_SRC
RUN <<CMD_LIST
    cd $LFS_SRC/glibc-2.36
    ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
    ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
    patch -Np1 -i ../glibc-2.36-fhs-1.patch
    mkdir -v build
CMD_LIST
WORKDIR $LFS_SRC/glibc-2.36/build

FROM glibc-src AS glibc-bld
RUN <<CMD_LIST
    echo "rootsbindir=/usr/sbin" > configparms
    ../configure --prefix=/usr --host=$LFS_TGT \
        --build=$(../scripts/config.guess) --enable-kernel=3.2 \
        --with-headers=$LFS/usr/include libc_cv_slibdir=/usr/lib
    make
CMD_LIST

FROM glibc-bld AS glibc
RUN <<CMD_LIST
    make DESTDIR=$LFS install
    sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd
    $LFS/tools/libexec/gcc/$LFS_TGT/12.2.0/install-tools/mkheaders
CMD_LIST

# --- Libstdc++: Chapter 5.6 ---
FROM prebuild AS libstdc-src
COPY --from=glibc $LFS $LFS
ADD sources/gcc-12.2.0.tar.xz $LFS_SRC
RUN mkdir -v $LFS_SRC/gcc-12.2.0/build
WORKDIR $LFS_SRC/gcc-12.2.0/build

FROM libstdc-src AS libstdc-bld
RUN <<CMD_LIST
    ../libstdc++-v3/configure --host=$LFS_TGT --build=$(../config.guess) \
        --prefix=/usr --disable-multilib --disable-nls --disable-libstdcxx-pch \
        --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/12.2.0
    make
CMD_LIST

FROM libstdc-bld AS libstdc
RUN <<CMD_LIST
    make DESTDIR=$LFS install
    rm -v $LFS/usr/lib/lib{stdc++,stdc++fs,supc++}.la
CMD_LIST

# --- M4: Chapter 6.2 ---
FROM prebuild AS m4-src
COPY --from=libstdc $LFS $LFS
ADD sources/m4-1.4.19.tar.xz $LFS_SRC
WORKDIR $LFS_SRC/m4-1.4.19

FROM m4-src AS m4-bld
RUN <<CMD_LIST
    ./configure --prefix=/usr --host=$LFS_TGT \
        --build=$(build-aux/config.guess)
    make
CMD_LIST

FROM m4-bld AS m4
RUN make DESTDIR=$LFS install

# --- Ncurses: Chapter 6.3 ---
FROM prebuild AS ncurses-src
COPY --from=m4 $LFS $LFS
ADD sources/ncurses-6.3.tar.gz $LFS_SRC
WORKDIR $LFS_SRC/ncurses-6.3
RUN <<CMD_LIST
    sed -i s/mawk// configure
    mkdir -v build
CMD_LIST

FROM ncurses-src AS ncurses-bld
RUN <<CMD_LIST
    cd build
    ../configure
    make -C include
    make -C progs tic
    cd ..
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess) \
        --mandir=/usr/share/man --with-manpage-format=normal \
        --with-shared --without-normal --with-cxx-shared --without-debug \
        --without-ada --disable-stripping --enable-widec
    make
CMD_LIST

FROM ncurses-bld AS ncurses
RUN <<CMD_LIST
    make DESTDIR=$LFS TIC_PATH=$(pwd)/build/progs/tic install
    echo "INPUT(-lncursesw)" > $LFS/usr/lib/libncurses.so
CMD_LIST

# --- Bash: Chapter 6.4 ---
FROM prebuild AS bash-src
COPY --from=ncurses $LFS $LFS
ADD sources/bash-5.1.16.tar.gz $LFS_SRC
WORKDIR $LFS_SRC/bash-5.1.16

FROM bash-src AS bash-bld
RUN <<CMD_LIST
    ./configure --prefix=/usr --build=$(support/config.guess) \
        --host=$LFS_TGT --without-bash-malloc
    make
CMD_LIST

FROM bash-bld AS bash
RUN <<CMD_LIST
    make DESTDIR=$LFS install
    ln -sv bash $LFS/bin/sh
CMD_LIST

# --- Coreutils: Chapter 6.5 ---
FROM prebuild AS coreutils-src
COPY --from=bash $LFS $LFS
ADD sources/coreutils-9.1.tar.xz $LFS_SRC
WORKDIR $LFS_SRC/coreutils-9.1

FROM coreutils-src AS coreutils-bld
RUN <<CMD_LIST
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess) \
        --enable-install-program=hostname --enable-no-install-program=kill,uptime
    make
CMD_LIST

FROM coreutils-bld AS coreutils
RUN <<CMD_LIST
    make DESTDIR=$LFS install
    mv -v $LFS/usr/{bin/chroot,sbin}
    mkdir -pv $LFS/usr/share/man/man8
    mv -v $LFS/usr/share/man/{man1/chroot.1,man8/chroot.8}
    sed -i 's/"1"/"8"/' $LFS/usr/share/man/man8/chroot.8
CMD_LIST

# --- Diffutils: Chapter 6.6 ---
FROM prebuild AS diffutils-src
COPY --from=coreutils $LFS $LFS
ADD sources/diffutils-3.8.tar.xz $LFS_SRC
WORKDIR $LFS_SRC/diffutils-3.8

FROM diffutils-src AS diffutils-bld
RUN <<CMD_LIST
    ./configure --prefix=/usr --host=$LFS_TGT
    make
CMD_LIST

FROM diffutils-bld AS diffutils
RUN make DESTDIR=$LFS install

# --- File: Chapter 6.7 ---
FROM prebuild AS file-src
COPY --from=diffutils $LFS $LFS
ADD sources/file-5.42.tar.gz $LFS_SRC
WORKDIR $LFS_SRC/file-5.42
RUN mkdir -v build

FROM file-src AS file-bld
RUN <<CMD_LIST
    cd build
    ../configure --disable-bzlib --disable-libseccomp \
        --disable-xzlib --disable-zlib
    make
    cd ..
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)
    make FILE_COMPILE=$(pwd)/build/src/file
CMD_LIST

FROM file-bld AS file
RUN <<CMD_LIST
    make DESTDIR=$LFS install
    rm -v $LFS/usr/lib/libmagic.la
CMD_LIST

# --- Findutils: Chapter 6.8 ---
FROM prebuild AS findutils-src
COPY --from=file $LFS $LFS
ADD sources/findutils-4.9.0.tar.xz $LFS_SRC
WORKDIR $LFS_SRC/findutils-4.9.0

FROM findutils-src AS findutils-bld
RUN <<CMD_LIST
    ./configure --prefix=/usr --localstatedir=/var/lib/locate \
        --host=$LFS_TGT --build=$(build-aux/config.guess)
    make
CMD_LIST

FROM findutils-bld AS findutils
RUN make DESTDIR=$LFS install

# --- Gawk: Chapter 6.9 ---
FROM prebuild AS gawk-src
COPY --from=findutils $LFS $LFS
ADD sources/gawk-5.1.1.tar.xz $LFS_SRC
WORKDIR $LFS_SRC/gawk-5.1.1
RUN sed -i 's/extras//' Makefile.in

FROM gawk-src AS gawk-bld
RUN <<CMD_LIST
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
    make
CMD_LIST

FROM gawk-bld AS gawk
RUN make DESTDIR=$LFS install

# --- Grep: Chapter 6.10 ---
FROM prebuild AS grep-src
COPY --from=gawk $LFS $LFS
ADD sources/grep-3.7.tar.xz $LFS_SRC
WORKDIR $LFS_SRC/grep-3.7

FROM grep-src AS grep-bld
RUN <<CMD_LIST
    ./configure --prefix=/usr --host=$LFS_TGT
    make
CMD_LIST

FROM grep-bld AS grep
RUN make DESTDIR=$LFS install

# --- Gzip: Chapter 6.11 ---
FROM prebuild AS gzip-src
COPY --from=grep $LFS $LFS
ADD sources/gzip-1.12.tar.xz $LFS_SRC
WORKDIR $LFS_SRC/gzip-1.12

FROM gzip-src AS gzip-bld
RUN <<CMD_LIST
    ./configure --prefix=/usr --host=$LFS_TGT
    make
CMD_LIST

FROM gzip-bld AS gzip
RUN make DESTDIR=$LFS install

# --- Make: Chapter 6.12 ---
FROM prebuild AS make-src
COPY --from=gzip $LFS $LFS
ADD sources/make-4.3.tar.gz $LFS_SRC
WORKDIR $LFS_SRC/make-4.3

FROM make-src AS make-bld
RUN <<CMD_LIST
    ./configure --prefix=/usr --without-guile --host=$LFS_TGT \
        --build=$(build-aux/config.guess)
    make
CMD_LIST

FROM make-bld AS make
RUN make DESTDIR=$LFS install

# --- Patch: Chapter 6.13 ---
FROM prebuild AS patch-src
COPY --from=make $LFS $LFS
ADD sources/patch-2.7.6.tar.xz $LFS_SRC
WORKDIR $LFS_SRC/patch-2.7.6

FROM patch-src AS patch-bld
RUN <<CMD_LIST
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
    make
CMD_LIST

FROM patch-bld AS patch
RUN make DESTDIR=$LFS install

# --- Sed: Chapter 6.14 ---
FROM prebuild AS sed-src
COPY --from=patch $LFS $LFS
ADD sources/sed-4.8.tar.xz $LFS_SRC
WORKDIR $LFS_SRC/sed-4.8

FROM sed-src AS sed-bld
RUN <<CMD_LIST
    ./configure --prefix=/usr --host=$LFS_TGT
    make
CMD_LIST

FROM sed-bld AS sed
RUN make DESTDIR=$LFS install

# --- Tar: Chapter 6.15 ---
FROM prebuild AS tar-src
COPY --from=sed $LFS $LFS
ADD sources/tar-1.34.tar.xz $LFS_SRC
WORKDIR $LFS_SRC/tar-1.34

FROM tar-src AS tar-bld
RUN <<CMD_LIST
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
    make
CMD_LIST

FROM tar-bld AS tar
RUN make DESTDIR=$LFS install

# --- Xz: Chapter 6.16 ---
FROM prebuild AS xz-src
COPY --from=tar $LFS $LFS
ADD sources/xz-5.2.6.tar.xz $LFS_SRC
WORKDIR $LFS_SRC/xz-5.2.6

FROM xz-src AS xz-bld
RUN <<CMD_LIST
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess) \
        --disable-static --docdir=/usr/share/doc/xz-5.2.6
    make
CMD_LIST

FROM xz-bld AS xz
RUN <<CMD_LIST
    make DESTDIR=$LFS install
    rm -v $LFS/usr/lib/liblzma.la
CMD_LIST

# --- Binutils 2nd pass: Chapter 6.17 ---
FROM prebuild AS binutils2-src
COPY --from=xz $LFS $LFS
ADD sources/binutils-2.39.tar.xz $LFS_SRC
RUN <<CMD_LIST
    cd $LFS_SRC/binutils-2.39
    sed '6009s/$add_dir//' -i ltmain.sh
    mkdir -v build
CMD_LIST
WORKDIR $LFS_SRC/binutils-2.39/build

FROM binutils2-src AS binutils2-bld
RUN <<CMD_LIST
    ../configure --prefix=/usr --build=$(../config.guess) --host=$LFS_TGT \
        --disable-nls --enable-shared --enable-gprofng=no \
        --disable-werror --enable-64-bit-bfd
    make
CMD_LIST

FROM binutils2-bld AS binutils2
RUN <<CMD_LIST
    make DESTDIR=$LFS install
    rm -v $LFS/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes}.{a,la}
CMD_LIST

# --- GCC 2nd pass: Chapter 6.18 ---
FROM prebuild AS gcc2-src
COPY --from=binutils2 $LFS $LFS
ADD sources/gcc-12.2.0.tar.xz $LFS_SRC
ADD sources/gmp-6.2.1.tar.xz $LFS_SRC/gcc-12.2.0
ADD sources/mpc-1.2.1.tar.gz $LFS_SRC/gcc-12.2.0
ADD sources/mpfr-4.1.0.tar.xz $LFS_SRC/gcc-12.2.0
RUN <<CMD_LIST
    cd $LFS_SRC/gcc-12.2.0
    mv gmp-6.2.1 gmp
    mv mpc-1.2.1 mpc
    mv mpfr-4.1.0 mpfr
    sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
    sed '/thread_header =/s/@.*@/gthr-posix.h/' \
        -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in
    mkdir -v build
CMD_LIST
WORKDIR $LFS_SRC/gcc-12.2.0/build

FROM gcc2-src AS gcc2-bld
RUN <<CMD_LIST
    ../configure --build=$(../config.guess) --host=$LFS_TGT --target=$LFS_TGT \
        LDFLAGS_FOR_TARGET=-L$PWD/$LFS_TGT/libgcc --prefix=/usr \
        --with-build-sysroot=$LFS --enable-initfini-array --disable-nls \
        --disable-multilib --disable-decimal-float --disable-libatomic \
        --disable-libgomp --disable-libquadmath --disable-libssp \
        --disable-libvtv --enable-languages=c,c++
    make
CMD_LIST

FROM gcc2-bld AS gcc2
RUN <<CMD_LIST
    make DESTDIR=$LFS install
    ln -sv gcc $LFS/usr/bin/cc
CMD_LIST

# --- Chroot environment: Chapter 7, Sections 1-6 ---
FROM scratch AS chroot
LABEL maintainer="Ron Hatch <ronhatch@earthlink.net>"
COPY --from=gcc2 /lfs /
COPY scripts/passwd scripts/group /etc/
ENV PS1='(LFS chroot) \u:\w\$ '
ENV PATH=/usr/sbin:/usr/bin
ENV LFS=/lfs
ENV LFS_SRC=/sources
CMD ["/bin/bash", "+h", "-c"]
RUN <<CMD_LIST
    rm -rf /tools
    mkdir -pv $LFS_SRC
    mkdir -pv /{boot,home,mnt,opt,srv}
    mkdir -pv /etc/{opt,sysconfig}
    mkdir -pv /lib/firmware
    mkdir -pv /media/{floppy,cdrom}
    mkdir -pv /usr/{,local/}{include,src}
    mkdir -pv /usr/local/{bin,lib,sbin}
    mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,misc,terminfo,zoneinfo}
    mkdir -pv /usr/{,local/}share/man/man{1..8}
    mkdir -pv /var/{cache,local,log,mail,opt,spool}
    mkdir -pv /var/lib/{color,misc,locate}
    ln -sfv /run /var/run
    ln -sfv /run/lock /var/lock
    install -dv -m 0750 /root
    install -dv -m 1777 /tmp /var/tmp
    ln -sv /proc/self/mounts /etc/mtab
    install -o 101 -d /home/tester
    touch /var/log/{btmp,lastlog,faillog,wtmp}
    chgrp -v utmp /var/log/lastlog
    chmod -v 664 /var/log/lastlog
    chmod -v 600 /var/log/btmp
CMD_LIST

# --- Gettext: Chapter 7.7 ---
FROM chroot AS gettext-bld
ADD sources/gettext-0.21.tar.xz $LFS_SRC
WORKDIR $LFS_SRC/gettext-0.21
RUN <<CMD_LIST
    ./configure --disable-shared
    make
CMD_LIST

FROM gettext-bld AS gettext
RUN cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin

# --- Bison: Chapter 7.8 ---
FROM gettext AS bison-bld
ADD sources/bison-3.8.2.tar.xz $LFS_SRC
WORKDIR $LFS_SRC/bison-3.8.2
RUN <<CMD_LIST
    ./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2
    make
CMD_LIST

FROM bison-bld AS bison
RUN make install

# --- Perl: Chapter 7.9 ---
FROM bison AS perl-bld
ADD sources/perl-5.36.0.tar.xz $LFS_SRC
WORKDIR $LFS_SRC/perl-5.36.0
RUN <<CMD_LIST
    sh Configure -des -Dprefix=/usr -Dvendorprefix=/usr \
        -Dprivlib=/usr/lib/perl5/5.36/core_perl \
        -Darchlib=/usr/lib/perl5/5.36/core_perl \
        -Dsitelib=/usr/lib/perl5/5.36/site_perl \
        -Dsitearch=/usr/lib/perl5/5.36/site_perl \
        -Dvendorlib=/usr/lib/perl5/5.36/vendor_perl \
        -Dvendorarch=/usr/lib/perl5/5.36/vendor_perl
    make
CMD_LIST

FROM perl-bld AS perl
RUN make install

# --- Python: Chapter 7.10 ---
FROM perl AS python-bld
ADD sources/Python-3.11.1.tar.xz $LFS_SRC
WORKDIR $LFS_SRC/Python-3.11.1
RUN <<CMD_LIST
    ./configure --prefix=/usr --enable-shared --without-ensurepip
    make
CMD_LIST

FROM python-bld AS python
RUN make install

# --- Texinfo: Chapter 7.11 ---
FROM perl AS texinfo
ADD sources/texinfo-6.8.tar.xz $LFS_SRC
WORKDIR $LFS_SRC/texinfo-6.8
RUN <<CMD_LIST
    ./configure --prefix=/usr
     make
CMD_LIST
RUN cat <<-INSTALL > ../texinfo-install.sh
	make DESTDIR=$LFS install
INSTALL

# --- Util-linux: Chapter 7.12 ---
FROM chroot AS util-linux
ADD sources/util-linux-2.38.1.tar.xz $LFS_SRC
WORKDIR $LFS_SRC/util-linux-2.38.1
RUN <<CMD_LIST
    mkdir -pv /var/lib/hwclock
    ./configure ADJTIME_PATH=/var/lib/hwclock/adjtime --libdir=/usr/lib \
        --docdir=/usr/share/doc/util-linux-2.38.1 --disable-chfn-chsh \
        --disable-login --disable-nologin --disable-su --disable-setpriv \
        --disable-runuser --disable-pylibmount --disable-static \
        --without-python runstatedir=/run
    make
CMD_LIST
RUN cat <<-INSTALL > ../util-linux-install.sh
	make DESTDIR=$LFS install
INSTALL

# --- Cleanup: Chapter 7.13 ---
FROM texinfo AS cleanup
ADD --link tarballs/texinfo.tar.gz .
ADD --link tarballs/util-linux.tar.gz .
RUN <<CMD_LIST
    rm -rf $LFS_SRC /usr/share/{info,man,doc}/*
    find /usr/{lib,libexec} -name \*.la -delete
CMD_LIST

# --- Final build system: Ready for Chapter 8 and on ---
FROM scratch AS builder
LABEL maintainer="Ron Hatch <ronhatch@earthlink.net>"
COPY --from=cleanup / /
ENV PS1='(LFS builder) \u:\w\$ '
ENV PATH=/usr/sbin:/usr/bin
CMD ["/bin/bash", "+h", "-c"]
