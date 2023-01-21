# NOTE: This isn't going to work under Windows CMD.
# TODO: Fix the entire piping to a log file issue.
SHELL = /bin/bash
.SHELLFLAGS = -o pipefail -c

vpath %.log    build-logs
vpath %.ok     status
vpath %.tar.gz tarballs

status/builder.ok: cleanup.ok
status/cleanup.ok: util-linux.tar.gz texinfo.tar.gz python.tar.gz
status/util-linux.ok: chroot.log | build-logs status
status/texinfo.ok: perl.log | build-logs status
status/python.ok: perl.log | build-logs status

tarballs/util-linux.tar.gz: util-linux.ok
tarballs/texinfo.tar.gz: texinfo.ok | md5sums tarballs
tarballs/python.tar.gz: python.ok | md5sums tarballs

status/%.ok:
	docker build --target=$* -t ronhatch/lfs-$* . 2>&1 | tee build-logs/$*.log
	touch $@

tarballs/%.tar.gz: %.ok
	docker run --rm -v fakeroot:/lfs ronhatch/lfs-$* \
	/bin/sh /sources/$*-install.sh | tee build-logs/$*-install.log
	docker run --rm -v fakeroot:/lfs -w /lfs ubuntu \
	find -type f -exec md5sum '{}' \; > md5sums/$*.txt
	docker run --rm -v fakeroot:/lfs -v $(CURDIR)/tarballs:/mnt -w /lfs ubuntu \
	tar czf /mnt/$*.tar.gz .
	docker volume rm fakeroot

build-logs:
	mkdir build-logs
md5sums:
	mkdir md5sums
status:
	mkdir status
tarballs:
	mkdir tarballs

.PHONY: clean
clean:
	rm status/*.ok tarballs/*.tar.gz

