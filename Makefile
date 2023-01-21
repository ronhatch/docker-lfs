vpath %.log    build-logs
vpath %.ok     status
vpath %.tar.gz tarballs

status/builder.ok: cleanup.ok
status/cleanup.ok: util-linux.tar.gz
status/util-linux.ok: texinfo.log | build-logs status

status/%.ok:
	docker build --target=$* -t ronhatch/lfs-$* . 2>&1 | tee build-logs/$*.log
	touch $@

tarballs/util-linux.tar.gz: util-linux.ok | md5sums tarballs
	docker run --rm -v fakeroot:/lfs ronhatch/lfs-util-linux \
	/bin/sh /sources/util-linux-install.sh | tee build-logs/util-linux-install.log
	docker run --rm -v fakeroot:/lfs -w /lfs ubuntu \
	find -type f -exec md5sum '{}' \; > md5sums/util-linux.txt
	docker run --rm -v fakeroot:/lfs -v $(CURDIR)/tarballs:/mnt -w /lfs ubuntu \
	tar czf /mnt/util-linux.tar.gz .
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

