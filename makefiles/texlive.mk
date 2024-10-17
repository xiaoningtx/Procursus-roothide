ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS   += texlive
TEXLIVE_VERSION := 2024.2
DEB_TEXLIVE_V   ?= $(TEXLIVE_VERSION)

ifneq ($(wildcard $(BUILD_WORK)/texlive/.CRLFtoLF_done),)
texlive-setup: setup
	@echo "texlive already converted to LF. "
else
texlive-setup: setup
	$(call GIT_CLONE,https://github.com/TeX-Live/texlive-source.git,tags/texlive-$(TEXLIVE_VERSION),texlive)
	find $(BUILD_WORK)/texlive \( ! -regex '.*/\..*' \) -type f -exec dos2unix -f {} \;
	touch $(BUILD_WORK)/texlive/.CRLFtoLF_done
	#$(call DO_PATCH,texlive,texlive,-p1)
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

	mkdir -p $(BUILD_WORK)/texlive/host
	cd $(BUILD_WORK)/texlive/host && CC= CXX= CPP= AR= LD= RANLIB= STRINGS= STRIP= I_N_T= NM= LIPO= OTOOL= LIBTOOL= \
	../configure -C $(BUILD_CONFIGURE_FLAGS) --disable-native-texlive-build --disable-xindy --disable-all-pkgs --without-x --enable-web2c --with-system-icu
	$(MAKE) -C $(BUILD_WORK)/texlive/host
	
	mkdir -p $(BUILD_WORK)/texlive/host/bin
	cp $(BUILD_WORK)/texlive/host/texk/web2c/himktables $(BUILD_WORK)/texlive/host/bin/

	mkdir -p $(BUILD_WORK)/texlive/build
	cd $(BUILD_WORK)/texlive/build && ../configure -C \
		$(DEFAULT_CONFIGURE_FLAGS) --disable-native-texlive-build  \
		--with-system-harfbuzz --with-system-icu \
		--with-system-teckit --with-system-graphite2 \
		--with-system-zziplib --with-system-mpfi \
		--with-system-mpfr --with-system-gmp \
		--with-system-cairo --with-system-pixman \
		--with-system-gd --with-system-potrace \
		--with-system-freetype2 --with-system-libpng \
		--with-system-libpaper --with-system-zlib \
		--disable-xindy CXXFLAGS='-std=c++17'
	
	# using the host web2c/web2c for cross building
	rm -rf $(BUILD_WORK)/texlive/build/texk/web2c/web2c
	mkdir -p $(BUILD_WORK)/texlive/build/texk/web2c
	cp -ar $(BUILD_WORK)/texlive/host/texk/web2c/web2c $(BUILD_WORK)/texlive/build/texk/web2c/
	
	PATH="$$PATH:$(BUILD_WORK)/texlive/host/bin" \
	$(MAKE) -C $(BUILD_WORK)/texlive/build
	
	$(MAKE) -C $(BUILD_WORK)/texlive/build install DESTDIR=$(BUILD_STAGE)/texlive
	
	$(call AFTER_BUILD)
endif

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
