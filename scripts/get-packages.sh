#!/bin/bash
apt update
apt -y install wget
cd /mnt/sources
wget -i - << FILE_LIST
https://ftp.gnu.org/gnu/glibc/glibc-2.36.tar.xz
https://www.kernel.org/pub/linux/kernel/v6.x/linux-6.0.11.tar.xz
https://www.linuxfromscratch.org/patches/lfs/11.2/glibc-2.36-fhs-1.patch
FILE_LIST
