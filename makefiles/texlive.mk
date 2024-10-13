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
texlive: texlive-setup cairo fontconfig freetype graphite2 harfbuzz icu4c libgd libgmp10 libpixman libpaper libpng16 libx11 libxaw mpfi mpfr4 potrace teckit zlib-ng zziplib
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
        --disable-xindy
	+$(MAKE) -C $(BUILD_WORK)/texlive/build
	+$(MAKE) -C $(BUILD_WORK)/texlive install \
		DESTDIR=$(BUILD_STAGE)/texlive
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
