vpath %.log    build-logs
vpath %.ok     status
vpath %.tar.gz tarballs

status/builder.ok: cleanup.ok
status/cleanup.ok: util-linux.tar.gz
status/util-linux.ok: texinfo.log | build-logs status

tarballs/util-linux.tar.gz: | md5sums tarballs

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

