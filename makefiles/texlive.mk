ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS   += texlive
TEXLIVE_VERSION := 2024.2
DEB_TEXLIVE_V   ?= $(TEXLIVE_VERSION)

TLROOT=$(BUILD_STAGE)/texlive$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/texlive
ORIGINAL_BIN_DIR=$(BUILD_STAGE)/texlive$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin
TEXLIVE_INSTALL_ENV_NOCHECK=1

ifneq ($(wildcard $(BUILD_WORK)/texlive/.CRLFtoLF_done),)
texlive-setup: setup
	@echo "texlive already converted to LF. "
else
texlive-setup: setup
	$(call GIT_CLONE,https://github.com/TeX-Live/texlive-source.git,tags/texlive-$(TEXLIVE_VERSION),texlive)
	$(call GIT_CLONE,https://github.com/TeX-Live/installer.git,master,texlive/installer)
	find $(BUILD_WORK)/texlive \( ! -regex '.*/\..*' \) -type f -exec dos2unix -f {} \;
	touch $(BUILD_WORK)/texlive/.CRLFtoLF_done
endif

ifneq ($(wildcard $(BUILD_WORK)/texlive/.build_complete),)
texlive:
	@echo "Using previously built texlive."
else
texlive: texlive-setup cairo fontconfig freetype graphite2 harfbuzz icu4c libgd libgmp10 libpixman libpaper libpng16 libx11 libxaw libmpfi mpfr4 potrace teckit zlib-ng zziplib

	# using the target AR instead of host AR
	sed -i "s|AR = ar|AR = @AR@|" $(BUILD_WORK)/texlive/libs/xpdf/Makefile.in
	sed -i "s|ac_subst_vars='am__EXEEXT_FALSE|ac_subst_vars='AR\nam__EXEEXT_FALSE|" $(BUILD_WORK)/texlive/libs/xpdf/configure
	
	# when cross compiling, we must use himktables from PATH
	sed -i 's%./himktables$$(EXEEXT)%eval $$(shell command -v himktables >/dev/null 2>\&1 \&\& echo himktables || echo ./himktables)$$(EXEEXT)%' $(BUILD_WORK)/texlive/texk/web2c/Makefile.in

	# when cross installing we must use build binaries instead of host ones
	sed -i 's|my $$plat_bindir = "$$TEXDIR/bin/$$vars{'"'"'this_platform'"'"'}"|my $$plat_bindir = ""|' $(BUILD_WORK)/texlive/installer/install-tl

	# build some tools explicitly for build (otherwise texlive explodes):
	# 1 - configure for build
	mkdir -p $(BUILD_WORK)/texlive/host
	cd $(BUILD_WORK)/texlive/host && \
		CC= CXX= CPP= AR= LD= RANLIB= STRINGS= STRIP= I_N_T= NM= \
		LIPO= OTOOL= LIBTOOL= ../configure \
		-C $(BUILD_CONFIGURE_FLAGS) --disable-native-texlive-build \
		--disable-xindy --disable-all-pkgs --without-x \
		--enable-web2c --with-system-icu
	# 2 - make for build
	$(MAKE) -C $(BUILD_WORK)/texlive/host

	# 3 - copy the result where we need it
	mkdir -p $(BUILD_WORK)/texlive/host/bin
	cp $(BUILD_WORK)/texlive/host/texk/web2c/himktables \
		$(BUILD_WORK)/texlive/host/bin/

	# finally build texlive for host
	# 1 - configure for host
	mkdir -p $(BUILD_WORK)/texlive/build
	cd $(BUILD_WORK)/texlive/build && ../configure -C \
		$(DEFAULT_CONFIGURE_FLAGS) --disable-native-texlive-build \
		--with-system-harfbuzz --with-system-icu \
		--with-system-teckit --with-system-graphite2 \
		--with-system-zziplib --with-system-mpfi \
		--with-system-mpfr --with-system-gmp \
		--with-system-cairo --with-system-pixman \
		--with-system-gd --with-system-potrace \
		--with-system-freetype2 --with-system-libpng \
		--with-system-libpaper --with-system-zlib \
		--disable-xindy --with-banner-add='/iOS' \
		--datarootdir=$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/texlive \
		CXXFLAGS='-std=c++17'

	# using the host web2c/web2c for cross building
	rm -rf $(BUILD_WORK)/texlive/build/texk/web2c/web2c
	mkdir -p $(BUILD_WORK)/texlive/build/texk/web2c
	cp -ar $(BUILD_WORK)/texlive/host/texk/web2c/web2c \
		$(BUILD_WORK)/texlive/build/texk/web2c/

	# 2 - make for host
	PATH="$$PATH:$(BUILD_WORK)/texlive/host/bin" \
	$(MAKE) -C $(BUILD_WORK)/texlive/build

	# 3 - make install strip for host
	rm -rf $(BUILD_STAGE)/texlive
	$(MAKE) -C $(BUILD_WORK)/texlive/build world \
		DESTDIR=$(BUILD_STAGE)/texlive

	# create a working installation
	TEXLIVE_INSTALL_ENV_NOCHECK=1 TEXLIVE_INSTALL_NO_WELCOME=1 \
		$(BUILD_WORK)/texlive/installer/install-tl --no-interaction \
		-custom-bin $(BUILD_STAGE)/texlive$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin \
		-texdir $(TLROOT) -scheme scheme-minimal

	# fix what the installer did 'cause it sucks (can't preserve symlinks)
	rm -f $(TLROOT)/bin/custom/*
	cd $(TLROOT)/bin/custom/ && \
		for orig_file_path in $(ORIGINAL_BIN_DIR)/*; do \
			file_name=$$(basename -- $$orig_file_path); \
			if [ -L "$$orig_file_path" ]; then \
				real_orig_file_path=$$(realpath $$orig_file_path); \
				if [ "$$(dirname -- $$real_orig_file_path)" = "$(ORIGINAL_BIN_DIR)" ]; then \
					cp -a $$orig_file_path .; \
				else \
					ln -s $$(realpath --relative-to=. "$$orig_file_path") $$file_name; \
				fi \
			else \
				cp -a $$orig_file_path .; \
			fi \
		done

	# fix texlive package manager
	perl -pe 's/(?<=do_cmd_and_check)\s+//g' $(TLROOT)/texmf-dist/scripts/texlive/tlmgr.pl > $(TLROOT)/texmf-dist/scripts/texlive/temp.pl
	perl -pe 's/(?<=do_cmd_and_check)\s+//g' $(TLROOT)/texmf-dist/scripts/texlive/temp.pl > $(TLROOT)/texmf-dist/scripts/texlive/tlmgr.pl
	sed -i 's|do_cmd_and_check("|do_cmd_and_check("sudo |' $(TLROOT)/texmf-dist/scripts/texlive/tlmgr.pl
	rm $(TLROOT)/texmf-dist/scripts/texlive/temp.pl

	# remove original bin dir since the right binaries are the ones in TLROOT/bin/custom
	rm -rf $(BUILD_STAGE)/texlive$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin

	$(call AFTER_BUILD)
endif

texlive-install: texlive


texlive-package: texlive-stage
	# texlive.mk Package Structure
	rm -rf $(BUILD_DIST)/texlive

	# texlive.mk Prep texlive
	cp -a $(BUILD_STAGE)/texlive $(BUILD_DIST)

	# texlive.mk Sign
	$(call SIGN,texlive,general.xml)

	# texlive.mk Make .debs
	$(call PACK,texlive,DEB_TEXLIVE_V)

	# texlive.mk Build cleanup
	rm -rf $(BUILD_DIST)/texlive

.PHONY: texlive texlive-package
