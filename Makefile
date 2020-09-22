ROOTDIR = $(PWD)

# For reproducible binary installer builds
LC_ALL = C
DATE_EPOCH = '1970-01-01 00:00:00 GMT'

all: release/rpi-install.tgz

# Unpack the firmware initrd and inject all the bits and pieces that turns it
# into an installer initrd
buildd/initrdd:
	rm -rf $@/
	mkdir -p $@/
	cd  $@ && lz4cat $(ROOTDIR)/firmware/boot/firmware/initrd.img | cpio -i
	# Copy the installer init
	cp bin/init $@/
	# Copy additional binaries required by the installer
	cp -r firmware/usr/* $@/usr/
	cp bin/rpi-install $@/usr/bin/
	# Remove unnecessary files
	rm -rf $@/lib/firmware $@/lib/modules

# Rebuild the installer initrd
buildd/initrd.img: buildd/initrdd
	find $< | xargs touch -h -d $(DATE_EPOCH)
	cd $< && find . | sort | cpio --reproducible -H newc -o | gzip -9 > \
		$(ROOTDIR)/$@

buildd/install: buildd/initrd.img
	rm -rf $@/
	mkdir -p $@/
	cp -r firmware/boot/firmware/* $@/
	cp buildd/initrd.img $@/
	cp boot/*.txt $@/

release/rpi-install.tgz: buildd/install
	find $< | xargs touch -h -d $(DATE_EPOCH)
	cd buildd && tar --sort=name --owner=0 --group=0 --numeric-owner \
		-czf $(ROOTDIR)/$@ install/

release: clean release/rpi-install.tgz
	# Create a new CHANGELOG entry
	version=$$(head -1 CHANGELOG) ; \
	minor=$${version##*.} ; \
	new_version=$${version%.*}.$$(($${minor} + 1)) ; \
	{ echo "$${new_version}" ; \
	  git log --format='  * %s' "$${version}.." ; \
	  cat CHANGELOG ; } > .changelog
	mv .changelog CHANGELOG

	# Commit and tag the release
	version=$$(head -1 CHANGELOG) ; \
	git commit -s -m "rpi-install $${version}" -- \
		CHANGELOG release/rpi-install.tgz ; \
	git tag -s -m "rpi-install $${version}" "$${version}"

clean:
	rm -rf buildd

.PHONY: release
