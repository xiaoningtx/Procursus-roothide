ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS   += mpfi
MPFI_VERSION := 1.5.3
DEB_MPFI_V   ?= $(MPFI_VERSION)

ifneq ($(wildcard $(BUILD_WORK)/mpfi/.CRLFtoLF_done),)
mpfi-setup: setup
	@echo "mpfi already converted to LF. "
else
mpfi-setup: setup
	$(call GIT_CLONE,https://gitlab.inria.fr/mpfi/mpfi.git,master,mpfi)
	find $(BUILD_WORK)/mpfi \( ! -regex '.*/\..*' \) -type f -exec dos2unix -f {} \;
	touch $(BUILD_WORK)/mpfi/.CRLFtoLF_done
endif

ifneq ($(wildcard $(BUILD_WORK)/mpfi/.build_complete),)
mpfi:
	@echo "Using previously built mpfi."
else
mpfi: mpfi-setup
	cd $(BUILD_WORK)/mpfi && ./autogen.sh && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS)
	+$(MAKE) -C $(BUILD_WORK)/mpfi
	+$(MAKE) -C $(BUILD_WORK)/mpfi install \
		DESTDIR=$(BUILD_STAGE)/mpfi
	$(call AFTER_BUILD,copy)
endif

mpfi-package: mpfi-stage
	# mpfi.mk Package Structure
	rm -rf $(BUILD_DIST)/mpfi

	# mpfi.mk Prep mpfi
	cp -a $(BUILD_STAGE)/mpfi $(BUILD_DIST)

	# mpfi.mk Sign
	$(call SIGN,mpfi,general.xml)

	# mpfi.mk Make .debs
	$(call PACK,mpfi,DEB_MPFI_V)

	# mpfi.mk Build cleanup
	rm -rf $(BUILD_DIST)/mpfi

.PHONY: mpfi mpfi-package
