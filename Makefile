tarballs/util-linux.tar.gz: build-logs/util-linux-bld.log
	docker run --rm -v fakeroot:/lfs ronhatch/lfs-util-linux-bld \
        make DESTDIR=/lfs install | tee build-logs/util-linux.log
	docker run --name util-linux -v fakeroot:/lfs -v tarballs:/mnt -w /lfs \
        ubuntu tar czf /mnt/util-linux.tar.gz .
	docker cp util-linux:/mnt/util-linux.tar.gz tarballs
	docker rm util-linux
	docker volume rm fakeroot tarballs

