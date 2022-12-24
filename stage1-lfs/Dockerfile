FROM ronhatch/prebuild-lfs:11.2
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
