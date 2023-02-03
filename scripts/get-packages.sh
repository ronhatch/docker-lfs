#!/bin/bash
apt update
apt -y install wget
cd /mnt/sources
wget -i - << FILE_LIST
https://www.kernel.org/pub/linux/kernel/v6.x/linux-6.0.11.tar.xz
FILE_LIST
