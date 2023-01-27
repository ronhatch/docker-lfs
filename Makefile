# NOTE: This isn't going to work under Windows CMD.
# TODO: Fix the entire piping to a log file issue.
SHELL = /bin/bash
.SHELLFLAGS = -o pipefail -c
WGET_SRC = docker run --rm -v $(CURDIR)/sources:/mnt -w /mnt alpine wget

vpath %.log    build-logs
vpath %.ok     status
vpath %.tar.gz tarballs

chroot_pkgs := gettext bison perl python texinfo util-linux
chroot_imgs := $(addsuffix .ok, $(chroot_pkgs))
chroot_img_paths := $(addprefix status/, $(chroot_imgs))
chroot_tarballs := $(addsuffix .tar.gz, $(chroot_pkgs))
chroot_gz_paths := $(addprefix tarballs/, $(chroot_tarballs))

status/builder.ok: cleanup.ok
status/cleanup.ok: $(chroot_tarballs)
status/util-linux.ok: chroot.log sources/util-linux-2.38.1.tar.xz
status/texinfo.ok: perl.tar.gz
status/python.ok: perl.tar.gz
status/perl.ok: bison.tar.gz gettext.tar.gz
status/bison.ok: chroot.log
status/gettext.ok: chroot.log

$(chroot_img_paths): build-logs status

$(chroot_gz_paths): md5sums tarballs
$(chroot_gz_paths): tarballs/%.tar.gz: %.ok

status/%.ok:
	docker build --target=$* -t ronhatch/lfs-$* . 2>&1 | tee build-logs/$*.log
	touch $@

build-logs/%-test.log: %.ok
	-docker run --rm ronhatch/lfs-$* make test | tee build-logs/$*-test.log

tarballs/%.tar.gz: %.ok
	docker run --rm -v fakeroot:/lfs ronhatch/lfs-$* \
	/bin/sh /sources/$*-install.sh | tee build-logs/$*-install.log
	docker run --rm -v fakeroot:/lfs -w /lfs ubuntu \
	find -type f -exec md5sum '{}' \; > md5sums/$*.txt
	docker run --rm -v fakeroot:/lfs -v $(CURDIR)/tarballs:/mnt -w /lfs ubuntu \
	tar czf /mnt/$*.tar.gz .
	docker volume rm fakeroot

sources/util-linux-2.38.1.tar.xz:
	$(WGET_SRC) https://www.kernel.org/pub/linux/utils/util-linux/v2.38/util-linux-2.38.1.tar.xz

build-logs:
	mkdir build-logs
md5sums:
	mkdir md5sums
status:
	mkdir status
tarballs:
	mkdir tarballs

.PHONY: clean test
clean:
	rm status/*.ok tarballs/*.tar.gz
test: build-logs/perl-test.log build-logs/python-test.log

