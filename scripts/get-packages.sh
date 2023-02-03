#!/bin/bash
apt update
apt -y install wget
cd /mnt/sources
wget -i - << FILE_LIST
https://ftp.gnu.org/gnu/bash/bash-5.1.16.tar.gz
https://ftp.gnu.org/gnu/coreutils/coreutils-9.1.tar.xz
https://ftp.gnu.org/gnu/diffutils/diffutils-3.8.tar.xz
https://astron.com/pub/file/file-5.42.tar.gz
https://ftp.gnu.org/gnu/findutils/findutils-4.9.0.tar.xz
https://ftp.gnu.org/gnu/glibc/glibc-2.36.tar.xz
https://www.kernel.org/pub/linux/kernel/v6.x/linux-6.0.11.tar.xz
https://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.xz
https://invisible-mirror.net/archives/ncurses/ncurses-6.3.tar.gz
https://www.linuxfromscratch.org/patches/lfs/11.2/glibc-2.36-fhs-1.patch
FILE_LIST
