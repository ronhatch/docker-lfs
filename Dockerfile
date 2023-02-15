# syntax=docker/dockerfile:1
# Use BuildKit, needed for the heredoc feature.

# --- Prebuild environment: Chapters 1-4 ---
FROM alpine:3.16 AS prebuild
LABEL maintainer="Ron Hatch <ronhatch@earthlink.net>"
ENV DEST=/install
ENV LFS=/lfs
ENV LFS_SRC=/sources
ENV LC_ALL=POSIX
ENV PATH=$LFS/tools/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV LFS_TGT=x86_64-lfs-linux-gnu
ENV CONFIG_SITE=$LFS/usr/share/config.site
RUN apk add --no-cache bash binutils bison coreutils diffutils findutils \
    g++ gawk grep gzip m4 make patch perl python3 sed tar texinfo xz
SHELL ["/bin/bash", "+h", "-c"]
RUN <<CMD_LIST
    rm -f /bin/sh
    ln -sv bash /bin/sh
    mkdir -pv $LFS/{etc,lib64,tools,var} $LFS/usr/{bin,lib,sbin}
    for i in bin lib sbin; do
      ln -sv usr/$i $LFS/$is
    done
    mkdir -pv $LFS_SRC
CMD_LIST
COPY scripts/version-check.sh /root
WORKDIR /root

# --- Binutils 1st pass: Chapter 5.2 ---
FROM prebuild AS pre-binutils1
ADD sources/binutils-2.39.tar.xz $LFS_SRC
# https://ftp.gnu.org/gnu/binutils/binutils-2.39.tar.xz
RUN mkdir -v $LFS_SRC/binutils-2.39/build
WORKDIR $LFS_SRC/binutils-2.39/build
RUN <<CMD_LIST
    ../configure --prefix=$LFS/tools --with-sysroot=$LFS \
        --target=$LFS_TGT --disable-nls \
        --enable-gprofng=no --disable-werror
    make
CMD_LIST
RUN cat <<-INSTALL > ../../pre-binutils1-install.sh
	make DESTDIR=$DEST install
INSTALL

# --- GCC 1st pass: Chapter 5.3 ---
FROM prebuild AS pre-gcc1
ADD tarballs/pre-binutils1.tar.gz /
ADD sources/gcc-12.2.0.tar.xz $LFS_SRC
# https://ftp.gnu.org/gnu/gcc/gcc-12.2.0/gcc-12.2.0.tar.xz
ADD sources/gmp-6.2.1.tar.xz $LFS_SRC/gcc-12.2.0
# https://ftp.gnu.org/gnu/gmp/gmp-6.2.1.tar.xz
ADD sources/mpc-1.2.1.tar.gz $LFS_SRC/gcc-12.2.0
# https://ftp.gnu.org/gnu/mpc/mpc-1.2.1.tar.gz
ADD sources/mpfr-4.1.0.tar.xz $LFS_SRC/gcc-12.2.0
# https://ftp.gnu.org/gnu/mpfr/mpfr-4.1.0.tar.xz
RUN <<CMD_LIST
    cd $LFS_SRC/gcc-12.2.0
    mv gmp-6.2.1 gmp
    mv mpc-1.2.1 mpc
    mv mpfr-4.1.0 mpfr
    sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
    mkdir -v build
CMD_LIST
WORKDIR $LFS_SRC/gcc-12.2.0/build
RUN <<CMD_LIST
    ../configure --target=$LFS_TGT --prefix=$LFS/tools --with-glibc-version=2.36 \
        --with-sysroot=$LFS --with-newlib --without-headers --disable-nls \
        --disable-shared --disable-multilib --disable-decimal-float \
        --disable-threads --disable-libatomic --disable-libgomp \
        --disable-libquadmath --disable-libssp --disable-libvtv \
        --disable-libstdcxx --enable-languages=c,c++
    make
CMD_LIST
RUN cat <<-INSTALL > ../../pre-gcc1-install.sh
	make DESTDIR=$DEST install
	cd ..
	cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
	    \`dirname \$($DEST$LFS/tools/bin/$LFS_TGT-gcc -print-libgcc-file-name) \
	    \`/install-tools/include/limits.h
INSTALL

# --- Linux API headers: Chapter 5.4 ---
FROM prebuild AS pre-headers
ADD tarballs/pre-binutils1.tar.gz /
ADD tarballs/pre-gcc1.tar.gz /
ADD sources/linux-6.1.6.tar.xz $LFS_SRC
# https://www.kernel.org/pub/linux/kernel/v6.x/linux-6.1.6.tar.xz
WORKDIR $LFS_SRC/linux-6.1.6
RUN <<CMD_LIST
    make mrproper
    make headers
    find usr/include -type f ! -name '*.h' -delete
CMD_LIST
RUN cat <<-INSTALL > ../pre-headers-install.sh
	mkdir -pv $DEST/usr
	cp -rv usr/include $DEST/usr
INSTALL

# --- Glibc: Chapter 5.5 ---
FROM prebuild AS pre-glibc
ADD tarballs/pre-binutils1.tar.gz /
ADD tarballs/pre-gcc1.tar.gz /
ADD tarballs/pre-headers.tar.gz $LFS
ADD sources/glibc-2.36.tar.xz $LFS_SRC
# https://ftp.gnu.org/gnu/glibc/glibc-2.36.tar.xz
ADD sources/glibc-2.36-fhs-1.patch $LFS_SRC
# https://www.linuxfromscratch.org/patches/lfs/11.2/glibc-2.36-fhs-1.patch
RUN <<CMD_LIST
    cd $LFS_SRC/glibc-2.36
    ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
    ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
    patch -Np1 -i ../glibc-2.36-fhs-1.patch
    mkdir -v build
CMD_LIST
WORKDIR $LFS_SRC/glibc-2.36/build
RUN <<CMD_LIST
    echo "rootsbindir=/usr/sbin" > configparms
    ../configure --prefix=/usr --host=$LFS_TGT \
        --build=$(../scripts/config.guess) --enable-kernel=3.2 \
        --with-headers=$LFS/usr/include libc_cv_slibdir=/usr/lib
    make
CMD_LIST
RUN cat <<-INSTALL > ../../pre-glibc-install.sh
	cp -a $LFS/lib64 $DEST
	make DESTDIR=$DEST install
	sed '/RTLDLIST=/s@/usr@@g' -i $DEST/usr/bin/ldd
INSTALL

# --- 1st Bundle: Mainly used to reduce clutter for later stages ---
#     We finish the Glibc install instructions here, since it modifies
#     the GCC install and must be done in-place.
#     Also used for the compile chain sanity check from chapter 5.5.
FROM prebuild AS bundle1
ADD tarballs/pre-binutils1.tar.gz /
ADD tarballs/pre-gcc1.tar.gz /
ADD tarballs/pre-headers.tar.gz $LFS
ADD tarballs/pre-glibc.tar.gz $LFS
RUN <<CMD_LIST
	$LFS/tools/libexec/gcc/$LFS_TGT/12.2.0/install-tools/mkheaders
	echo "echo 'int main(){}' | $LFS_TGT-gcc -xc -" > /root/sanity-check.sh
	echo "readelf -l a.out | grep ld-linux" >> /root/sanity-check.sh
CMD_LIST

# --- Libstdc++: Chapter 5.6 ---
FROM bundle1 AS pre-libstdc
#     The GCC source package is required for an earlier stage.
ADD sources/gcc-12.2.0.tar.xz $LFS_SRC
RUN mkdir -v $LFS_SRC/gcc-12.2.0/build
WORKDIR $LFS_SRC/gcc-12.2.0/build
RUN <<CMD_LIST
    ../libstdc++-v3/configure --host=$LFS_TGT --build=$(../config.guess) \
        --prefix=/usr --disable-multilib --disable-nls --disable-libstdcxx-pch \
        --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/12.2.0
    make
CMD_LIST
RUN cat <<-INSTALL > ../../pre-libstdc-install.sh
	make DESTDIR=$DEST install
	rm -v $DEST/usr/lib/lib{stdc++,stdc++fs,supc++}.la
INSTALL

# --- M4: Chapter 6.2 ---
FROM bundle1 AS pre-m4
ADD tarballs/pre-libstdc.tar.gz $LFS
ADD sources/m4-1.4.19.tar.xz $LFS_SRC
# https://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.xz
WORKDIR $LFS_SRC/m4-1.4.19
RUN <<CMD_LIST
    ./configure --prefix=/usr --host=$LFS_TGT \
        --build=$(build-aux/config.guess)
    make
CMD_LIST
RUN cat <<-INSTALL > ../pre-m4-install.sh
	make DESTDIR=$DEST install
INSTALL

# --- Ncurses: Chapter 6.3 ---
FROM bundle1 AS pre-ncurses
ADD tarballs/pre-libstdc.tar.gz $LFS
ADD tarballs/pre-m4.tar.gz $LFS
ADD sources/ncurses-6.3.tar.gz $LFS_SRC
# https://invisible-mirror.net/archives/ncurses/ncurses-6.3.tar.gz
WORKDIR $LFS_SRC/ncurses-6.3
RUN <<CMD_LIST
    sed -i s/mawk// configure
    mkdir -v build
CMD_LIST
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
RUN cat <<-INSTALL > ../pre-ncurses-install.sh
	make DESTDIR=$DEST TIC_PATH=$(pwd)/build/progs/tic install
	echo "INPUT(-lncursesw)" > $DEST/usr/lib/libncurses.so
INSTALL

# --- Bash: Chapter 6.4 ---
FROM bundle1 AS pre-bash
ADD tarballs/pre-libstdc.tar.gz $LFS
ADD tarballs/pre-m4.tar.gz $LFS
ADD tarballs/pre-ncurses.tar.gz $LFS
ADD sources/bash-5.1.16.tar.gz $LFS_SRC
# https://ftp.gnu.org/gnu/bash/bash-5.1.16.tar.gz
WORKDIR $LFS_SRC/bash-5.1.16
RUN <<CMD_LIST
    ./configure --prefix=/usr --build=$(support/config.guess) \
        --host=$LFS_TGT --without-bash-malloc
    make
CMD_LIST
RUN cat <<-INSTALL > ../pre-bash-install.sh
	make DESTDIR=$DEST install
	ln -sv bash $DEST/usr/bin/sh
INSTALL

# --- Coreutils: Chapter 6.5 ---
FROM bundle1 AS pre-coreutils
ADD tarballs/pre-libstdc.tar.gz $LFS
ADD tarballs/pre-m4.tar.gz $LFS
ADD tarballs/pre-ncurses.tar.gz $LFS
ADD tarballs/pre-bash.tar.gz $LFS
ADD sources/coreutils-9.1.tar.xz $LFS_SRC
# https://ftp.gnu.org/gnu/coreutils/coreutils-9.1.tar.xz
WORKDIR $LFS_SRC/coreutils-9.1
RUN <<CMD_LIST
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess) \
        --enable-install-program=hostname --enable-no-install-program=kill,uptime
    make
CMD_LIST
RUN cat <<-INSTALL > ../pre-coreutils-install.sh
	make DESTDIR=$DEST install
	mv -v $DEST/usr/{bin/chroot,sbin}
	mkdir -pv $DEST/usr/share/man/man8
	mv -v $DEST/usr/share/man/{man1/chroot.1,man8/chroot.8}
	sed -i 's/"1"/"8"/' $DEST/usr/share/man/man8/chroot.8
INSTALL

# --- Diffutils: Chapter 6.6 ---
FROM bundle1 AS pre-diffutils
ADD tarballs/pre-libstdc.tar.gz $LFS
ADD tarballs/pre-m4.tar.gz $LFS
ADD tarballs/pre-ncurses.tar.gz $LFS
ADD tarballs/pre-bash.tar.gz $LFS
ADD tarballs/pre-coreutils.tar.gz $LFS
ADD sources/diffutils-3.8.tar.xz $LFS_SRC
# https://ftp.gnu.org/gnu/diffutils/diffutils-3.8.tar.xz
WORKDIR $LFS_SRC/diffutils-3.8
RUN <<CMD_LIST
    ./configure --prefix=/usr --host=$LFS_TGT
    make
CMD_LIST
RUN cat <<-INSTALL > ../pre-diffutils-install.sh
	make DESTDIR=$DEST install
INSTALL

# --- 2nd Bundle: Used to reduce clutter for later stages ---
FROM bundle1 AS bundle2
ADD tarballs/pre-libstdc.tar.gz $LFS
ADD tarballs/pre-m4.tar.gz $LFS
ADD tarballs/pre-ncurses.tar.gz $LFS
ADD tarballs/pre-bash.tar.gz $LFS
ADD tarballs/pre-coreutils.tar.gz $LFS
ADD tarballs/pre-diffutils.tar.gz $LFS

# --- File: Chapter 6.7 ---
FROM bundle2 AS pre-file
ADD sources/file-5.42.tar.gz $LFS_SRC
# https://astron.com/pub/file/file-5.42.tar.gz
WORKDIR $LFS_SRC/file-5.42
RUN mkdir -v build
RUN <<CMD_LIST
    cd build
    ../configure --disable-bzlib --disable-libseccomp \
        --disable-xzlib --disable-zlib
    make
    cd ..
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)
    make FILE_COMPILE=$(pwd)/build/src/file
CMD_LIST
RUN cat <<-INSTALL > ../pre-file-install.sh
	make DESTDIR=$DEST install
	rm -v $DEST/usr/lib/libmagic.la
INSTALL

# --- Findutils: Chapter 6.8 ---
FROM bundle2 AS pre-findutils
ADD tarballs/pre-file.tar.gz $LFS
ADD sources/findutils-4.9.0.tar.xz $LFS_SRC
# https://ftp.gnu.org/gnu/findutils/findutils-4.9.0.tar.xz
WORKDIR $LFS_SRC/findutils-4.9.0
RUN <<CMD_LIST
    ./configure --prefix=/usr --localstatedir=/var/lib/locate \
        --host=$LFS_TGT --build=$(build-aux/config.guess)
    make
CMD_LIST
RUN cat <<-INSTALL > ../pre-findutils-install.sh
	make DESTDIR=$DEST install
INSTALL

# --- Gawk: Chapter 6.9 ---
FROM bundle2 AS pre-gawk
ADD tarballs/pre-file.tar.gz $LFS
ADD tarballs/pre-findutils.tar.gz $LFS
ADD sources/gawk-5.1.1.tar.xz $LFS_SRC
# https://ftp.gnu.org/gnu/gawk/gawk-5.1.1.tar.xz
WORKDIR $LFS_SRC/gawk-5.1.1
RUN sed -i 's/extras//' Makefile.in
RUN <<CMD_LIST
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
    make
CMD_LIST
RUN cat <<-INSTALL > ../pre-gawk-install.sh
	make DESTDIR=$DEST install
INSTALL

# --- Grep: Chapter 6.10 ---
FROM bundle2 AS pre-grep
ADD tarballs/pre-file.tar.gz $LFS
ADD tarballs/pre-findutils.tar.gz $LFS
ADD tarballs/pre-gawk.tar.gz $LFS
ADD sources/grep-3.7.tar.xz $LFS_SRC
# https://ftp.gnu.org/gnu/grep/grep-3.7.tar.xz
WORKDIR $LFS_SRC/grep-3.7
RUN <<CMD_LIST
    ./configure --prefix=/usr --host=$LFS_TGT
    make
CMD_LIST
RUN cat <<-INSTALL > ../pre-grep-install.sh
	make DESTDIR=$DEST install
INSTALL

# --- Gzip: Chapter 6.11 ---
FROM bundle2 AS pre-gzip
ADD tarballs/pre-file.tar.gz $LFS
ADD tarballs/pre-findutils.tar.gz $LFS
ADD tarballs/pre-gawk.tar.gz $LFS
ADD tarballs/pre-grep.tar.gz $LFS
ADD sources/gzip-1.12.tar.xz $LFS_SRC
# https://ftp.gnu.org/gnu/gzip/gzip-1.12.tar.xz
WORKDIR $LFS_SRC/gzip-1.12
RUN <<CMD_LIST
    ./configure --prefix=/usr --host=$LFS_TGT
    make
CMD_LIST
RUN cat <<-INSTALL > ../pre-gzip-install.sh
	make DESTDIR=$DEST install
INSTALL

# --- Make: Chapter 6.12 ---
FROM bundle2 AS pre-make
ADD tarballs/pre-file.tar.gz $LFS
ADD tarballs/pre-findutils.tar.gz $LFS
ADD tarballs/pre-gawk.tar.gz $LFS
ADD tarballs/pre-grep.tar.gz $LFS
ADD tarballs/pre-gzip.tar.gz $LFS
ADD sources/make-4.3.tar.gz $LFS_SRC
# https://ftp.gnu.org/gnu/make/make-4.3.tar.gz
WORKDIR $LFS_SRC/make-4.3
RUN <<CMD_LIST
    ./configure --prefix=/usr --without-guile --host=$LFS_TGT \
        --build=$(build-aux/config.guess)
    make
CMD_LIST
RUN cat <<-INSTALL > ../pre-make-install.sh
	make DESTDIR=$DEST install
INSTALL

# --- 3rd Bundle: Used to reduce clutter for later stages ---
FROM bundle2 AS bundle3
ADD tarballs/pre-file.tar.gz $LFS
ADD tarballs/pre-findutils.tar.gz $LFS
ADD tarballs/pre-gawk.tar.gz $LFS
ADD tarballs/pre-grep.tar.gz $LFS
ADD tarballs/pre-gzip.tar.gz $LFS
ADD tarballs/pre-make.tar.gz $LFS

# --- Patch: Chapter 6.13 ---
FROM bundle3 AS pre-patch
ADD sources/patch-2.7.6.tar.xz $LFS_SRC
# https://ftp.gnu.org/gnu/patch/patch-2.7.6.tar.xz
WORKDIR $LFS_SRC/patch-2.7.6
RUN <<CMD_LIST
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
    make
CMD_LIST
RUN cat <<-INSTALL > ../pre-patch-install.sh
	make DESTDIR=$DEST install
INSTALL

# --- Sed: Chapter 6.14 ---
FROM bundle3 AS pre-sed
ADD tarballs/pre-patch.tar.gz $LFS
ADD sources/sed-4.8.tar.xz $LFS_SRC
# https://ftp.gnu.org/gnu/sed/sed-4.8.tar.xz
WORKDIR $LFS_SRC/sed-4.8
RUN <<CMD_LIST
    ./configure --prefix=/usr --host=$LFS_TGT
    make
CMD_LIST
RUN cat <<-INSTALL > ../pre-sed-install.sh
	make DESTDIR=$DEST install
INSTALL

# --- Tar: Chapter 6.15 ---
FROM bundle3 AS pre-tar
ADD tarballs/pre-patch.tar.gz $LFS
ADD tarballs/pre-sed.tar.gz $LFS
ADD sources/tar-1.34.tar.xz $LFS_SRC
# https://ftp.gnu.org/gnu/tar/tar-1.34.tar.xz
WORKDIR $LFS_SRC/tar-1.34
RUN <<CMD_LIST
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
    make
CMD_LIST
RUN cat <<-INSTALL > ../pre-tar-install.sh
	make DESTDIR=$DEST install
INSTALL

# --- Xz: Chapter 6.16 ---
FROM bundle3 AS pre-xz
ADD tarballs/pre-patch.tar.gz $LFS
ADD tarballs/pre-sed.tar.gz $LFS
ADD tarballs/pre-tar.tar.gz $LFS
ADD sources/xz-5.2.6.tar.xz $LFS_SRC
# https://tukaani.org/xz/xz-5.2.6.tar.xz
WORKDIR $LFS_SRC/xz-5.2.6
RUN <<CMD_LIST
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess) \
        --disable-static --docdir=/usr/share/doc/xz-5.2.6
    make
CMD_LIST
RUN cat <<-INSTALL > ../pre-xz-install.sh
	make DESTDIR=$DEST install
	rm -v $DEST/usr/lib/liblzma.la
INSTALL

# --- Binutils 2nd pass: Chapter 6.17 ---
FROM bundle3 AS pre-binutils2
ADD tarballs/pre-patch.tar.gz $LFS
ADD tarballs/pre-sed.tar.gz $LFS
ADD tarballs/pre-tar.tar.gz $LFS
ADD tarballs/pre-xz.tar.gz $LFS
#     The Binutils source package is required for an earlier stage.
ADD sources/binutils-2.39.tar.xz $LFS_SRC
RUN <<CMD_LIST
    cd $LFS_SRC/binutils-2.39
    sed '6009s/$add_dir//' -i ltmain.sh
    mkdir -v build
CMD_LIST
WORKDIR $LFS_SRC/binutils-2.39/build
RUN <<CMD_LIST
    ../configure --prefix=/usr --build=$(../config.guess) --host=$LFS_TGT \
        --disable-nls --enable-shared --enable-gprofng=no \
        --disable-werror --enable-64-bit-bfd
    make
CMD_LIST
RUN cat <<-INSTALL > ../../pre-binutils2-install.sh
	make DESTDIR=$DEST install
	rm -v $DEST/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes}.{a,la}
INSTALL

# --- GCC 2nd pass: Chapter 6.18 ---
FROM bundle3 AS pre-gcc2
ADD tarballs/pre-patch.tar.gz $LFS
ADD tarballs/pre-sed.tar.gz $LFS
ADD tarballs/pre-tar.tar.gz $LFS
ADD tarballs/pre-xz.tar.gz $LFS
ADD tarballs/pre-binutils2.tar.gz $LFS
#     The GCC source packages are required for an earlier stage.
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
RUN <<CMD_LIST
    ../configure --build=$(../config.guess) --host=$LFS_TGT --target=$LFS_TGT \
        LDFLAGS_FOR_TARGET=-L$PWD/$LFS_TGT/libgcc --prefix=/usr \
        --with-build-sysroot=$LFS --enable-initfini-array --disable-nls \
        --disable-multilib --disable-decimal-float --disable-libatomic \
        --disable-libgomp --disable-libquadmath --disable-libssp \
        --disable-libvtv --enable-languages=c,c++
    make
CMD_LIST
RUN cat <<-INSTALL > ../../pre-gcc2-install.sh
	make DESTDIR=$DEST install
	ln -sv gcc $DEST/usr/bin/cc
INSTALL

# --- Chroot environment: Chapter 7, Sections 1-6 ---
FROM scratch AS chroot
LABEL maintainer="Ron Hatch <ronhatch@earthlink.net>"
COPY --from=prebuild /lfs /
ADD tarballs/pre-headers.tar.gz /
ADD tarballs/pre-glibc.tar.gz /
ADD tarballs/pre-libstdc.tar.gz /
ADD tarballs/pre-m4.tar.gz /
ADD tarballs/pre-ncurses.tar.gz /
ADD tarballs/pre-bash.tar.gz /
ADD tarballs/pre-coreutils.tar.gz /
ADD tarballs/pre-diffutils.tar.gz /
ADD tarballs/pre-file.tar.gz /
ADD tarballs/pre-findutils.tar.gz /
ADD tarballs/pre-gawk.tar.gz /
ADD tarballs/pre-grep.tar.gz /
ADD tarballs/pre-gzip.tar.gz /
ADD tarballs/pre-make.tar.gz /
ADD tarballs/pre-patch.tar.gz /
ADD tarballs/pre-sed.tar.gz /
ADD tarballs/pre-tar.tar.gz /
ADD tarballs/pre-xz.tar.gz /
ADD tarballs/pre-binutils2.tar.gz /
ADD tarballs/pre-gcc2.tar.gz /
COPY scripts/passwd scripts/group /etc/
ENV PS1='(LFS chroot) \u:\w\$ '
ENV PATH=/usr/sbin:/usr/bin
ENV DEST=/install
ENV LFS_SRC=/sources
CMD ["/bin/bash", "+h", "-c"]
RUN <<CMD_LIST
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
FROM chroot AS pre-gettext
ADD sources/gettext-0.21.tar.xz $LFS_SRC
# https://ftp.gnu.org/gnu/gettext/gettext-0.21.tar.xz
WORKDIR $LFS_SRC/gettext-0.21
RUN <<CMD_LIST
    ./configure --disable-shared
    make
CMD_LIST
RUN cat <<-INSTALL > ../pre-gettext-install.sh
	mkdir -pv $DEST/usr/bin
	cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} $DEST/usr/bin
INSTALL

# --- Bison: Chapter 7.8 ---
FROM chroot AS pre-bison
ADD sources/bison-3.8.2.tar.xz $LFS_SRC
# https://ftp.gnu.org/gnu/bison/bison-3.8.2.tar.xz
WORKDIR $LFS_SRC/bison-3.8.2
RUN <<CMD_LIST
    ./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2
    make
CMD_LIST
RUN cat <<-INSTALL > ../pre-bison-install.sh
	make DESTDIR=$DEST install
INSTALL

# --- Perl: Chapter 7.9 ---
FROM chroot AS pre-perl
# Perl probably doesn't need all of these as prerequisites, but
#   since the build won't be exactly the same even if nothing was
#   changed, we can't test those prerequisites easily and it seems
#   safer to just include them in case.
ADD tarballs/pre-gettext.tar.gz /
ADD tarballs/pre-bison.tar.gz /
ADD sources/perl-5.36.0.tar.xz $LFS_SRC
# https://www.cpan.org/src/5.0/perl-5.36.0.tar.xz
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
RUN cat <<-INSTALL > ../pre-perl-install.sh
	make DESTDIR=$DEST install.perl
INSTALL

# --- Python: Chapter 7.10 ---
FROM chroot AS pre-python
# Python probably doesn't need all of these as prerequisites, but
#   since the build won't be exactly the same even if nothing was
#   changed, we can't test those prerequisites easily and it seems
#   safer to just include them in case.
ADD tarballs/pre-gettext.tar.gz /
ADD tarballs/pre-bison.tar.gz /
ADD tarballs/pre-perl.tar.gz /
ADD sources/Python-3.11.1.tar.xz $LFS_SRC
# https://www.python.org/ftp/python/3.11.1/Python-3.11.1.tar.xz
WORKDIR $LFS_SRC/Python-3.11.1
RUN <<CMD_LIST
    ./configure --prefix=/usr --enable-shared --without-ensurepip
    make
CMD_LIST
RUN cat <<-INSTALL > ../pre-python-install.sh
	make DESTDIR=$DEST install
INSTALL

# --- Texinfo: Chapter 7.11 ---
FROM chroot AS pre-texinfo
ADD tarballs/pre-perl.tar.gz /
ADD sources/texinfo-6.8.tar.xz $LFS_SRC
# https://ftp.gnu.org/gnu/texinfo/texinfo-6.8.tar.xz
WORKDIR $LFS_SRC/texinfo-6.8
RUN <<CMD_LIST
    ./configure --prefix=/usr
     make
CMD_LIST
RUN cat <<-INSTALL > ../pre-texinfo-install.sh
	make DESTDIR=$DEST install
INSTALL

# --- Util-linux: Chapter 7.12 ---
FROM chroot AS pre-util-linux
ADD sources/util-linux-2.38.1.tar.xz $LFS_SRC
# https://www.kernel.org/pub/linux/utils/util-linux/v2.38/util-linux-2.38.1.tar.xz
WORKDIR $LFS_SRC/util-linux-2.38.1
RUN <<CMD_LIST
    mkdir -pv /var/lib/hwclock
    ./configure ADJTIME_PATH=/var/lib/hwclock/adjtime --libdir=/usr/lib \
        --docdir=/usr/share/doc/util-linux-2.38.1 --disable-chfn-chsh \
        --disable-login --disable-nologin --disable-su --disable-setpriv \
        --disable-runuser --disable-pylibmount --disable-static \
        --without-python --runstatedir=/run --bindir=/usr/bin \
        --sbindir=/usr/sbin
    make
CMD_LIST
RUN cat <<-INSTALL > ../pre-util-linux-install.sh
	make DESTDIR=$DEST install
INSTALL

# --- Cleanup: Chapter 7.13 ---
FROM chroot AS cleanup
ADD tarballs/pre-gettext.tar.gz /
ADD tarballs/pre-bison.tar.gz /
ADD tarballs/pre-perl.tar.gz /
ADD tarballs/pre-python.tar.gz /
ADD tarballs/pre-texinfo.tar.gz /
ADD tarballs/pre-util-linux.tar.gz /
RUN <<CMD_LIST
    rm -rf $LFS_SRC /usr/share/{info,man,doc}/*
    find /usr/{lib,libexec} -name \*.la -delete
CMD_LIST

# --- Final build system: Ready for Chapter 8 and on ---
FROM scratch AS builder
LABEL maintainer="Ron Hatch <ronhatch@earthlink.net>"
COPY --from=cleanup / /
ENV DEST=/install
ENV LFS_SRC=/sources
ENV PS1='(LFS builder) \u:\w\$ '
ENV PATH=/usr/sbin:/usr/bin
CMD ["/bin/bash", "+h", "-c"]

# --- Man-pages: Chapter 8.3 ---
FROM builder AS man-pages
ADD sources/man-pages-5.13.tar.xz $LFS_SRC
# https://www.kernel.org/pub/linux/docs/man-pages/man-pages-5.13.tar.xz
WORKDIR $LFS_SRC/man-pages-5.13
RUN cat <<-INSTALL > ../man-pages-install.sh
	make prefix=$DEST/usr install
INSTALL

# --- Iana-etc: Chapter 8.4 ---
FROM builder AS iana-etc
ADD sources/iana-etc-20220812.tar.gz $LFS_SRC
# https://github.com/Mic92/iana-etc/releases/download/20220812/iana-etc-20220812.tar.gz
WORKDIR $LFS_SRC/iana-etc-20220812
RUN cat <<-INSTALL > ../iana-etc-install.sh
	mkdir -pv $DEST/etc
	cp services protocols $DEST/etc
INSTALL

# --- Glibc: Chapter 8.5 ---
FROM builder AS glibc
ADD packages/man-pages.tar.gz /
ADD packages/iana-etc.tar.gz /
ADD sources/glibc-2.36.tar.xz $LFS_SRC
ADD sources/glibc-2.36-fhs-1.patch $LFS_SRC
#     The Glibc source package and FHS patch are required for an earlier stage.
ADD sources/glibc-2.36-security_fix-1.patch $LFS_SRC
# https://linuxfromscratch.org/patches/downloads/glibc/glibc-2.36-security_fix-1.patch
RUN <<CMD_LIST
    cd $LFS_SRC/glibc-2.36
    patch -Np1 -i ../glibc-2.36-fhs-1.patch
    patch -Np1 -i ../glibc-2.36-security_fix-1.patch
    mkdir -v build
CMD_LIST
WORKDIR $LFS_SRC/glibc-2.36/build
ADD sources/tzdata2022c.tar.gz $LFS_SRC/glibc-2.36/build
# https://www.iana.org/time-zones/repository/releases/tzdata2022c.tar.gz
RUN <<CMD_LIST
    echo "rootsbindir=/usr/sbin" > configparms
    ../configure --prefix=/usr --disable-werror \
        --enable-kernel=3.2 --enable-stack-protector=strong \
        --with-headers=/usr/include libc_cv_slibdir=/usr/lib
    make
CMD_LIST
# Because of the long list of localedef commands, this install script is
#   loaded in from an external file instead of using the normal heredoc.
COPY scripts/glibc-install.sh $LFS_SRC
COPY scripts/nsswitch.conf $LFS_SRC

