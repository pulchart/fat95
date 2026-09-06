# Makefile for fat95 filesystem handler
#
# Usage: make [options] [target]
#   help - show detailed usage output

# Release version: YYYYMMDD package date + optional in-progress suffix
# (-dev, -rc1, ...). Empty suffix for a final release.
RELEASE_DATE = 20260906
VERSION_SUFFIX = -dev

# fat95 filesystem handler version
FAT95_MAJOR = 4
FAT95_MINOR = 0
FAT95_VERSION_SUFFIX = -dev
FAT95_DATE = 06.09.2026

# Tools versions
INSTALL95_MAJOR = 3
INSTALL95_MINOR = 19
INSTALL95_VERSION_SUFFIX =
INSTALL95_DATE = 25.01.2026

DD_MAJOR = 2
DD_MINOR = 3
DD_VERSION_SUFFIX =
DD_DATE = 16.08.2026

DEBUG95_MAJOR = 3
DEBUG95_MINOR = 19
DEBUG95_VERSION_SUFFIX =
DEBUG95_DATE = 25.01.2026

SETFILESIZE_MAJOR = 1
SETFILESIZE_MINOR = 1
SETFILESIZE_VERSION_SUFFIX =
SETFILESIZE_DATE = 25.01.2026

BOOT95_MAJOR = 3
BOOT95_MINOR = 19
BOOT95_VERSION_SUFFIX =
BOOT95_DATE = 25.01.2026

LSFSRES_MAJOR = 1
LSFSRES_MINOR = 0
LSFSRES_VERSION_SUFFIX =
LSFSRES_DATE = 16.05.2026

# Derived versions
VERSION = $(RELEASE_DATE)$(VERSION_SUFFIX)
# Human-readable date derived from RELEASE_DATE (YYYYMMDD -> DD.MM.YYYY)
DATE = $(shell echo "$(RELEASE_DATE)" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\3.\2.\1/')

FAT95_VERSION       = $(FAT95_MAJOR).$(FAT95_MINOR)$(FAT95_VERSION_SUFFIX)
INSTALL95_VERSION   = $(INSTALL95_MAJOR).$(INSTALL95_MINOR)$(INSTALL95_VERSION_SUFFIX)
DD_VERSION          = $(DD_MAJOR).$(DD_MINOR)$(DD_VERSION_SUFFIX)
DEBUG95_VERSION     = $(DEBUG95_MAJOR).$(DEBUG95_MINOR)$(DEBUG95_VERSION_SUFFIX)
SETFILESIZE_VERSION = $(SETFILESIZE_MAJOR).$(SETFILESIZE_MINOR)$(SETFILESIZE_VERSION_SUFFIX)
BOOT95_VERSION      = $(BOOT95_MAJOR).$(BOOT95_MINOR)$(BOOT95_VERSION_SUFFIX)
LSFSRES_VERSION     = $(LSFSRES_MAJOR).$(LSFSRES_MINOR)$(LSFSRES_VERSION_SUFFIX)

# ptable.library + lsptres versions/dates read from the ptable build stamps.
PLIB_VERSION    = $(firstword $(shell cat $(PTABLE_VERSION_FILE) 2>/dev/null))
PLIB_DATE       = $(word 2,$(shell cat $(PTABLE_VERSION_FILE) 2>/dev/null))
LSPTRES_VERSION = $(firstword $(shell cat $(PTABLE_LSPTRES_VERSION_FILE) 2>/dev/null))
LSPTRES_DATE    = $(word 2,$(shell cat $(PTABLE_LSPTRES_VERSION_FILE) 2>/dev/null))

# Component table driving TOOLS and the README/dist auto-gen blocks.
COMPONENTS = FAT95 INSTALL95 DD DEBUG95 SETFILESIZE BOOT95 LSFSRES PLIB LSPTRES

FAT95_NAME         = fat95
FAT95_KIND         = handler
INSTALL95_NAME     = install95
INSTALL95_KIND     = tool
INSTALL95_TARGET   = $(TARGET_INSTALL95)
DD_NAME            = dd
DD_KIND            = tool
DD_TARGET          = $(TARGET_DD)
DEBUG95_NAME       = debug95
DEBUG95_KIND       = tool
DEBUG95_TARGET     = $(TARGET_DEBUG95)
SETFILESIZE_NAME   = SetFileSize
SETFILESIZE_KIND   = tool
SETFILESIZE_TARGET = $(TARGET_SETFILESIZE)
BOOT95_NAME        = boot95
BOOT95_KIND        = tool
BOOT95_TARGET      = $(TARGET_BOOT95)
LSFSRES_NAME       = lsfsres
LSFSRES_KIND       = tool
LSFSRES_TARGET     = $(TARGET_LSFSRES)
# Bundled from the ptable repo.
PLIB_NAME          = ptable.library
PLIB_KIND          = library
LSPTRES_NAME       = lsptres
LSPTRES_KIND       = tool
LSPTRES_TARGET     = dist/c/lsptres

# CPU tiers for the handler fan-out (tools stay single-tier).
CPUS = 68080 68020 68000

# Archive drawer per artifact kind; the handler lives in l/, the library in libs/.
_drawer_handler = l
_drawer_library = libs

# Per-component "name:target:version:date" entries; handler fans out over $(CPUS).
# A fanned-out artifact is named by its archive-relative path, so two tiers of the
# same file never share a line in the readme CHECKSUMS block.
define _artifact_entries
$(if $(filter tool,$($(1)_KIND)),\
$($(1)_NAME):$($(1)_TARGET):$($(1)_VERSION):$($(1)_DATE),\
$(foreach c,$(CPUS),$(_drawer_$($(1)_KIND))/$(c)/$($(1)_NAME):$(DISTDIR)/$(_drawer_$($(1)_KIND))/$(c)/$($(1)_NAME):$($(1)_VERSION):$($(1)_DATE)))
endef

# "PREFIX|name|version|date" per component, fed to tools/components.sh
# (the README.md block and the .readme list both render from this).
COMPONENT_ARGS = $(foreach c,$(COMPONENTS),'$(c)|$($(c)_NAME)|$($(c)_VERSION)|$($(c)_DATE)')

# Component summary with literal `\n` for GNU sed substitution; plain
# text (no markdown), changed-since-previous-tag components flagged "(new)".
COMPONENT_VERSIONS_NL = $(shell sh tools/components.sh plain $(COMPONENT_ARGS))

# Generate version include files for assembler
VERSION_FAT95_INC = src/fat95_version.i
VERSION_INSTALL95_INC = src/install95_version.i
VERSION_DD_INC = src/dd_version.i
VERSION_DEBUG95_INC = src/debug95_version.i
VERSION_SETFILESIZE_INC = src/setfilesize_version.i
VERSION_BOOT95_INC = src/boot95_version.i
VERSION_LSFSRES_INC = src/lsfsres_version.i

# Verbose mode (V=1 for verbose output)
ifeq ($(V),1)
  Q =
  DEFINITIONS =
else
  Q = @
  DEFINITIONS = -quiet
endif

# Build tools
VASM_HOME ?= /opt/vasm
VASM = $(VASM_HOME)/bin/vasmm68k_mot
EXPECTED_VASM_VERSION = 2.0e

# Flags
# VASMFLAGS is the base set shared by both CPU tiers; per-tier CPU flag
# (-m68020 -D__68020__=1 / -m68000) is appended in the individual build
# rules below.  Tools are always built 68000 (single tier).
VASMFLAGS = -Fhunkexe -nosym $(DEFINITIONS)

# CPU tier flags
# -D__68020__=1 enables the 020+ inline math paths (mulu.l / divul.l /
# bfffo) inside src/fat95.s via the UMUL32 / UDIVMOD32 / LOG2 macros.
# Must not be set for the 68000 tier or tools.
# -D__68080__=1 adds the Apollo 68080 paths on top of the 020+ ones,
# so the 080 tier sets both.
VASMCPU_080 = -m68020 -D__68080__=1 -D__68020__=1
# APOLLOON=1 adds the LineA opcodes (clr.q, movs.b) and the SR write that
# enables them. Off by default: they take a line-A exception on an
# IceDrake V4. Must stay undefined when off, not defined as 0, because
# vasm's ifd tests definedness only.
APOLLOON ?= 0
ifeq ($(APOLLOON),1)
VASMCPU_080 += -DAPOLLOON=1
endif
VASMCPU_020 = -m68020 -D__68020__=1
VASMCPU_000 = -m68000

# Directories
SRCDIR = src
DISTDIR = dist
OUTDIR = $(DISTDIR)/l
OUTDIR_080 = $(OUTDIR)/68080
OUTDIR_020 = $(OUTDIR)/68020
OUTDIR_000 = $(OUTDIR)/68000

# ptable.library repo (override PTABLE= to point at a local checkout). Bundled
# into the release LIBS: so whole-disk auto-detect works without it in ROM.
PTABLE ?= extern/ptable
PTABLE_VERSION_FILE = $(PTABLE)/dist/ptable.version
PTABLE_LSPTRES_VERSION_FILE = $(PTABLE)/dist/lsptres.version

# Files: Driver
SOURCE = $(SRCDIR)/fat95.s
TARGET_080 = $(OUTDIR_080)/fat95
TARGET_020 = $(OUTDIR_020)/fat95
TARGET_000 = $(OUTDIR_000)/fat95
DRIVER_TARGETS = $(TARGET_080) $(TARGET_020) $(TARGET_000)

# Files: Tools
SOURCE_INSTALL95 = $(SRCDIR)/install95.s
TARGET_INSTALL95 = $(OUTDIR)/install95

SOURCE_DD = $(SRCDIR)/dd.s
TARGET_DD = dist/c/dd

SOURCE_DEBUG95 = $(SRCDIR)/debug95.s
TARGET_DEBUG95 = dist/c/debug95

SOURCE_SETFILESIZE = $(SRCDIR)/setfilesize.s
TARGET_SETFILESIZE = dist/c/SetFileSize

SOURCE_BOOT95 = $(SRCDIR)/boot95.s
TARGET_BOOT95 = dist/c/boot95

SOURCE_LSFSRES = $(SRCDIR)/lsfsres.s
TARGET_LSFSRES = dist/c/lsfsres

# Files: Release
RELEASE_NAME = fat95.v$(VERSION)
ARCHIVE_NAME = $(RELEASE_NAME).lha
README_NAME = $(RELEASE_NAME).readme
README_TEMPLATE = dist.readme.in
README_INFO = dist/fat95.readme.info
LHA = lha

# ============================================================
# Build targets
# ============================================================

# Default target: build both CPU tiers + all tools
all: check-vasm version-readme $(DRIVER_TARGETS) $(TARGET_INSTALL95) $(TARGET_DD) $(TARGET_DEBUG95) $(TARGET_SETFILESIZE) $(TARGET_BOOT95) $(TARGET_LSFSRES)

# Generate version include file (always check, only update if changed)
# Uses a stamp file to track the current version string
VERSION_STAMP = .version-stamp
.PHONY: FORCE
FORCE:

$(VERSION_STAMP): FORCE
	$(Q)echo "$(VERSION) $(DATE) $(foreach c,$(COMPONENTS),$($(c)_VERSION) $($(c)_DATE))" > $(VERSION_STAMP).tmp
	$(Q)if ! cmp -s $(VERSION_STAMP).tmp $(VERSION_STAMP) 2>/dev/null; then \
		mv $(VERSION_STAMP).tmp $(VERSION_STAMP); \
	else \
		rm -f $(VERSION_STAMP).tmp; \
	fi

# Build ptable.library (small) + lsptres in the ptable repo and stage the
# built artifacts into dist/ for the release; nothing ptable-owned is rebuilt
# here, so every release ships the ptable-built bytes. MD2GUIDE/NDK are passed
# as absolute paths: the submodule's own relative defaults do not resolve from
# inside extern/ptable. Phony; a missing $(PTABLE) is a soft skip.
.PHONY: ptable-bundle
ptable-bundle:
	$(Q)if [ -f "$(PTABLE)/Makefile" ]; then \
		$(MAKE) -C "$(PTABLE)" all guides MD2GUIDE=$(abspath $(MD2GUIDE)) NDK=$(abspath NDK) >/dev/null; \
		mkdir -p dist/libs/68020 dist/libs/68000 dist/c $(GUIDE_OUTPUT_DIR); \
		cp "$(PTABLE)/dist/small/68020/ptable.library" dist/libs/68020/; \
		cp "$(PTABLE)/dist/small/68000/ptable.library" dist/libs/68000/; \
		cp "$(PTABLE)/dist/c/lsptres" dist/c/lsptres; \
		cp "$(PTABLE)/dist/docs/lsptres.guide" $(GUIDE_OUTPUT_DIR)/; \
		echo "  bundled ptable.library (small) + lsptres from $(PTABLE)"; \
	else \
		echo "  NOTE: $(PTABLE) absent - ptable.library / lsptres not bundled"; \
	fi

# Move the ptable checkout to its upstream tip and rebuild everything that
# bundles it. Uses the branch tip rather than "git submodule update": if the
# recorded commit was orphaned by an upstream history rewrite, restoring the
# pin would fail. Leaves the result uncommitted for review. Phony; a $(PTABLE)
# that is not a git checkout is a soft skip.
.PHONY: ptable-sync
ptable-sync:
	$(Q)if [ -e "$(PTABLE)/.git" ]; then \
		git -C "$(PTABLE)" fetch origin; \
		git -C "$(PTABLE)" checkout --detach origin/master; \
		$(MAKE) all; \
		echo "  ptable synced to $$(git -C "$(PTABLE)" rev-parse --short HEAD) ($$(cat $(PTABLE_VERSION_FILE)))"; \
		echo "  review, then commit $(PTABLE) with the rebuilt dist/ artifacts"; \
	else \
		echo "  NOTE: $(PTABLE) is not a git checkout - nothing to sync"; \
	fi

# version-readme reads the ptable stamps for the PLIB/LSPTRES component versions,
# so the bundle (which builds them) must run first.
version-readme: ptable-bundle
	$(Q)sed -i '0,/^## [0-9]\{8\}[^[:space:]]*/s/^## [0-9]\{8\}[^[:space:]]*/## $(VERSION)/' docs/changes.md
	$(Q)block="_Components in this release_:\n\n$$(sh tools/components.sh md $(COMPONENT_ARGS))"; \
	awk -v block="$$block" ' \
	    /<!-- COMPONENTS:BEGIN -->/{print; print block; in_block=1; next} \
	    /<!-- COMPONENTS:END -->/{in_block=0} \
	    !in_block' docs/changes.md > docs/changes.md.tmp && mv docs/changes.md.tmp docs/changes.md
	$(Q)echo "  CHANGES topmost header + components updated to $(VERSION) ($(DATE))"

# Version include file generation
# Parameters: 1=file, 2=name, 3=major, 4=minor, 5=version, 6=macro_name, 7=date, 8=add_lf_null
COMMA := ,
define gen_version_inc
	$(Q)echo "  VERSION $(2) $(5)" >&2
	$(Q)echo "; Auto-generated by Makefile." > $(1)
	$(if $(3),$(Q)echo "FILE_VERSION	= $(3)" >> $(1))
	$(if $(4),$(Q)echo "FILE_REVISION	= $(4)" >> $(1))
	$(Q)echo "$(6)	macro" >> $(1)
	$(Q)echo "	dc.b	\"\$$VER: $(2) $(5) ($(7))\"$(if $(8),$(COMMA) LF$(COMMA) 0)" >> $(1)
	$(Q)echo "	endm" >> $(1)
	$(Q)echo "VER_NUMBER	macro" >> $(1)
	$(Q)echo "	dc.b	\"$(5)\"" >> $(1)
	$(Q)echo "	endm" >> $(1)
endef

# Generate version include files
# fat95 uses a custom rule to emit a CPU-tier tag ([68080] / [68020] /
# [68000]) in the VERSION_STRING, selected at assembly time via
# nested `ifd __68080__` / `ifd __68020__`.
$(VERSION_FAT95_INC): $(VERSION_STAMP)
	$(Q)echo "  VERSION fat95 $(FAT95_VERSION)" >&2
	$(Q)echo "; Auto-generated by Makefile." > $@
	$(Q)echo "FILE_VERSION	= $(FAT95_MAJOR)" >> $@
	$(Q)echo "FILE_REVISION	= $(FAT95_MINOR)" >> $@
	$(Q)echo "VERSION_STRING	macro" >> $@
	$(Q)echo "	ifd	__68080__" >> $@
	$(Q)echo "	dc.b	\"\$$VER: fat95 $(FAT95_VERSION) ($(FAT95_DATE)) [68080]\"" >> $@
	$(Q)echo "	else" >> $@
	$(Q)echo "	ifd	__68020__" >> $@
	$(Q)echo "	dc.b	\"\$$VER: fat95 $(FAT95_VERSION) ($(FAT95_DATE)) [68020]\"" >> $@
	$(Q)echo "	else" >> $@
	$(Q)echo "	dc.b	\"\$$VER: fat95 $(FAT95_VERSION) ($(FAT95_DATE)) [68000]\"" >> $@
	$(Q)echo "	endc" >> $@
	$(Q)echo "	endc" >> $@
	$(Q)echo "	endm" >> $@

$(VERSION_INSTALL95_INC): $(VERSION_STAMP)
	$(call gen_version_inc,$@,install95,$(INSTALL95_MAJOR),$(INSTALL95_MINOR),$(INSTALL95_VERSION),VER_STRING,$(INSTALL95_DATE),1)

$(VERSION_DD_INC): $(VERSION_STAMP)
	$(call gen_version_inc,$@,dd,,,$(DD_VERSION),VER_STRING,$(DD_DATE),1)

$(VERSION_DEBUG95_INC): $(VERSION_STAMP)
	$(call gen_version_inc,$@,debug95,,,$(DEBUG95_VERSION),VER_STRING,$(DEBUG95_DATE),1)

$(VERSION_SETFILESIZE_INC): $(VERSION_STAMP)
	$(call gen_version_inc,$@,SetFileSize,,,$(SETFILESIZE_VERSION),VER_STRING,$(SETFILESIZE_DATE),1)

$(VERSION_BOOT95_INC): $(VERSION_STAMP)
	$(call gen_version_inc,$@,boot95,$(BOOT95_MAJOR),$(BOOT95_MINOR),$(BOOT95_VERSION),VER_STRING,$(BOOT95_DATE),1)

$(VERSION_LSFSRES_INC): $(VERSION_STAMP)
	$(call gen_version_inc,$@,lsfsres,,,$(LSFSRES_VERSION),VER_STRING,$(LSFSRES_DATE),1)

# Build fat95 handler, Apollo 68080 tier
$(TARGET_080): $(SOURCE) $(VERSION_FAT95_INC)
	$(Q)mkdir -p $(OUTDIR_080)
	$(Q)echo "  VASM    $@ [68080]"
	$(Q)$(VASM) $(VASMFLAGS) $(VASMCPU_080) -o $@ $<
	$(Q)echo "          $$(stat -c%s $@) bytes, md5:$$(md5sum $@ | cut -c1-8)"

# Build fat95 handler, 68020+ tier
$(TARGET_020): $(SOURCE) $(VERSION_FAT95_INC)
	$(Q)mkdir -p $(OUTDIR_020)
	$(Q)echo "  VASM    $@ [68020+]"
	$(Q)$(VASM) $(VASMFLAGS) $(VASMCPU_020) -o $@ $<
	$(Q)echo "          $$(stat -c%s $@) bytes, md5:$$(md5sum $@ | cut -c1-8)"

# Build fat95 handler, 68000 tier
$(TARGET_000): $(SOURCE) $(VERSION_FAT95_INC)
	$(Q)mkdir -p $(OUTDIR_000)
	$(Q)echo "  VASM    $@ [68000]"
	$(Q)$(VASM) $(VASMFLAGS) $(VASMCPU_000) -o $@ $<
	$(Q)echo "          $$(stat -c%s $@) bytes, md5:$$(md5sum $@ | cut -c1-8)"

# Build tools (single tier: 68000)
$(TARGET_INSTALL95): $(SOURCE_INSTALL95) $(VERSION_INSTALL95_INC)
	$(Q)mkdir -p $(OUTDIR)
	$(Q)echo "  VASM    $@"
	$(Q)$(VASM) $(VASMFLAGS) $(VASMCPU_000) -o $@ $<
	$(Q)echo "          $$(stat -c%s $@) bytes, md5:$$(md5sum $@ | cut -c1-8)"

$(TARGET_DD): $(SOURCE_DD) $(VERSION_DD_INC)
	$(Q)mkdir -p c
	$(Q)echo "  VASM    $@"
	$(Q)$(VASM) $(VASMFLAGS) $(VASMCPU_000) -o $@ $<
	$(Q)echo "          $$(stat -c%s $@) bytes, md5:$$(md5sum $@ | cut -c1-8)"

$(TARGET_DEBUG95): $(SOURCE_DEBUG95) $(VERSION_DEBUG95_INC)
	$(Q)mkdir -p c
	$(Q)echo "  VASM    $@"
	$(Q)$(VASM) $(VASMFLAGS) $(VASMCPU_000) -o $@ $<
	$(Q)echo "          $$(stat -c%s $@) bytes, md5:$$(md5sum $@ | cut -c1-8)"

$(TARGET_SETFILESIZE): $(SOURCE_SETFILESIZE) $(VERSION_SETFILESIZE_INC)
	$(Q)mkdir -p c
	$(Q)echo "  VASM    $@"
	$(Q)$(VASM) $(VASMFLAGS) $(VASMCPU_000) -o $@ $<
	$(Q)echo "          $$(stat -c%s $@) bytes, md5:$$(md5sum $@ | cut -c1-8)"

$(TARGET_BOOT95): $(SOURCE_BOOT95) $(VERSION_BOOT95_INC)
	$(Q)mkdir -p c
	$(Q)echo "  VASM    $@"
	$(Q)$(VASM) $(VASMFLAGS) $(VASMCPU_000) -o $@ $<
	$(Q)echo "          $$(stat -c%s $@) bytes, md5:$$(md5sum $@ | cut -c1-8)"

$(TARGET_LSFSRES): $(SOURCE_LSFSRES) $(VERSION_LSFSRES_INC)
	$(Q)mkdir -p c
	$(Q)echo "  VASM    $@"
	$(Q)$(VASM) $(VASMFLAGS) $(VASMCPU_000) -o $@ $<
	$(Q)echo "          $$(stat -c%s $@) bytes, md5:$$(md5sum $@ | cut -c1-8)"

# Convenience phonies per tier
fat95: check-vasm $(DRIVER_TARGETS)
fat95-080: check-vasm $(TARGET_080)
fat95-020: check-vasm $(TARGET_020)
fat95-000: check-vasm $(TARGET_000)
install95: check-vasm $(TARGET_INSTALL95)
dd: check-vasm $(TARGET_DD)
debug95: check-vasm $(TARGET_DEBUG95)
setfilesize: check-vasm $(TARGET_SETFILESIZE)
boot95: check-vasm $(TARGET_BOOT95)
lsfsres: check-vasm $(TARGET_LSFSRES)

# ============================================================
# Release targets
# ============================================================

# List of all tools for checksum generation (tool_name:target_file:version:date pairs)
# fat95 is listed twice, once per CPU tier, so both appear in the readme.
TOOLS = $(foreach c,$(COMPONENTS),$(call _artifact_entries,$(c)))
TOOLS_TARGETS = $(DRIVER_TARGETS) $(TARGET_INSTALL95) $(TARGET_DD) $(TARGET_DEBUG95) $(TARGET_SETFILESIZE) $(TARGET_BOOT95) $(TARGET_LSFSRES)

# Generate readme from template
$(README_NAME): $(README_TEMPLATE) $(TOOLS_TARGETS)
	@echo "Generating $(README_NAME) from template..."
	@# Generate checksum sections for all tools
	@tool_checksums=""; \
	for tool_info in $(TOOLS); do \
		tool_name=$$(echo "$$tool_info" | cut -d: -f1); \
		tool_target=$$(echo "$$tool_info" | cut -d: -f2); \
		tool_version=$$(echo "$$tool_info" | cut -d: -f3); \
		tool_date=$$(echo "$$tool_info" | cut -d: -f4); \
		if [ -f "$$tool_target" ]; then \
			tool_size=$$(stat -c%s "$$tool_target" 2>/dev/null || echo 0); \
			tool_md5=$$(md5sum "$$tool_target" 2>/dev/null | cut -d' ' -f1 || echo "N/A"); \
			tool_sha256=$$(sha256sum "$$tool_target" 2>/dev/null | cut -d' ' -f1 || echo "N/A"); \
			tool_checksums="$$tool_checksums$$tool_name $$tool_version ($$tool_date) ($$tool_size bytes):\n  MD5:    $$tool_md5\n  SHA256: $$tool_sha256\n\n"; \
		fi; \
	done; \
	sed -e "s|@VERSION@|$(VERSION)|g" \
		-e "s|@DATE@|$(DATE)|g" \
		-e "s|@COMPONENT_VERSIONS@|$(COMPONENT_VERSIONS_NL)|" \
		-e "s|@TOOL_CHECKSUMS@|$$tool_checksums|" \
		$(README_TEMPLATE) > $@
	@echo "Generated: $@"

# Generate readme only
readme: $(README_NAME)

# Check if vasm is installed and expected version
check-vasm:
	@[ -x "$(VASM)" ] || { \
		echo "ERROR: vasm command not found: $(VASM)"; \
		echo "Set VASM_HOME to your vasm installation (expected $(EXPECTED_VASM_VERSION))"; \
		exit 1; \
	}
	@version_output="$$( $(VASM) -v 2>&1 )"; \
	detected_version="$$( printf '%s\n' "$$version_output" | sed '/./!d' | sed -n '1p' )"; \
	case "$$version_output" in \
		*"$(EXPECTED_VASM_VERSION)"*) ;; \
		*) \
			echo "ERROR: unsupported vasm version!"; \
			echo "Expected: $(EXPECTED_VASM_VERSION)"; \
			echo "Detected: $${detected_version:-<no output>}"; \
			exit 1; \
			;; \
	esac

# Check if lha is installed
check-lha:
	@command -v $(LHA) >/dev/null 2>&1 || { echo "ERROR: lha not found (sudo dnf install lha)"; exit 1; }

# Create Aminet-compatible LHA release
release: check-vasm version-readme all $(README_NAME) guide check-lha
	@echo "Creating $(ARCHIVE_NAME)..."
	@S=$$(mktemp -d); \
	mkdir -p "$$S/fat95/l/68080" "$$S/fat95/l/68020" "$$S/fat95/l/68000" "$$S/fat95/c" "$$S/fat95/src"; \
	cp $(TARGET_080) "$$S/fat95/l/68080/"; \
	cp $(TARGET_020) "$$S/fat95/l/68020/"; \
	cp $(TARGET_000) "$$S/fat95/l/68000/"; \
	cp $(TARGET_INSTALL95) "$$S/fat95/l/"; \
	cp dist/c/* "$$S/fat95/c/"; \
	cp src/*.s src/*.i "$$S/fat95/src/"; \
	cp $(README_NAME) "$$S/fat95/fat95.readme"; \
	cp $(README_INFO) LICENSE "$$S/fat95/"; \
	if [ -d dist/libs ]; then \
		cp -r dist/libs "$$S/fat95/"; \
		echo "  bundled ptable.library (small) + lsptres (staged by ptable-bundle)"; \
	else \
		echo "  NOTE: $(PTABLE) absent - ptable.library / lsptres not bundled"; \
	fi; \
	mkdir -p "$$S/fat95/docs"; \
	cp $(GUIDE_FAT95)   "$$S/fat95/docs/"; \
	cp $(GUIDE_CHANGES) "$$S/fat95/docs/"; \
	cp $(GUIDE_DD)      "$$S/fat95/docs/"; \
	cp $(GUIDE_LSFSRES) "$$S/fat95/docs/"; \
	[ -f $(GUIDE_LSPTRES) ] && cp $(GUIDE_LSPTRES) "$$S/fat95/docs/" || true; \
	cp dist.info "$$S/fat95.info"; \
	for d in dist/DOSDrivers dist/english dist/deutsch dist/magyar dist/polska dist/russian dist/espa* dist/fran*; do \
		[ -d "$$d" ] && cp -r "$$d" "$$S/fat95/"; \
	done; \
	for f in dist/*.info; do [ -f "$$f" ] && cp "$$f" "$$S/fat95/"; done; \
	(cd "$$S" && LC_ALL=C $(LHA) c "$(ARCHIVE_NAME)" fat95 fat95.info 2>&1 | grep -v "iconv\|multibyte\|Invalid"); \
	mv "$$S/$(ARCHIVE_NAME)" . && rm -rf "$$S"; \
	echo "Created: $(ARCHIVE_NAME)" && $(LHA) l "$(ARCHIVE_NAME)"; \
	echo ""; echo "For Aminet upload:"; echo "  1. $(ARCHIVE_NAME)"; echo "  2. $(README_NAME)"

# ============================================================
# Utility targets
# ============================================================

# Clean build artifacts
clean:
	rm -f $(DRIVER_TARGETS) $(TARGET_INSTALL95) $(TARGET_DD) $(TARGET_DEBUG95) $(TARGET_SETFILESIZE) $(TARGET_BOOT95) $(TARGET_LSFSRES)
	rm -f $(VERSION_FAT95_INC) $(VERSION_INSTALL95_INC) $(VERSION_DD_INC) $(VERSION_DEBUG95_INC) $(VERSION_SETFILESIZE_INC) $(VERSION_BOOT95_INC) $(VERSION_LSFSRES_INC) $(VERSION_STAMP)
	rm -rf dist/libs dist/c/lsptres $(GUIDE_LSPTRES)
	$(Q)[ ! -d $(OUTDIR_080) ] || rmdir --ignore-fail-on-non-empty $(OUTDIR_080)
	$(Q)[ ! -d $(OUTDIR_020) ] || rmdir --ignore-fail-on-non-empty $(OUTDIR_020)
	$(Q)[ ! -d $(OUTDIR_000) ] || rmdir --ignore-fail-on-non-empty $(OUTDIR_000)

# Clean everything including release files
distclean: clean
	rm -f fat95*.readme fat95*.readme.info fat95*.lha

# Show help
help:
	@echo "Usage: make [V=1] [target]"
	@echo ""
	@echo "Build targets:"
	@echo "  all         - Build fat95 (both CPU tiers) + all tools (default)"
	@echo "  fat95       - Build fat95 (both CPU tiers) only"
	@echo "  fat95-020   - Build fat95 68020+ tier only"
	@echo "  fat95-000   - Build fat95 68000 tier only"
	@echo "  install95   - Build install95 tool only"
	@echo "  dd          - Build dd tool only"
	@echo "  debug95     - Build debug95 tool only"
	@echo "  setfilesize - Build SetFileSize tool only"
	@echo "  boot95      - Build boot95 tool only"
	@echo "  lsfsres     - Build lsfsres FileSystem.resource dumper only"
	@echo ""
	@echo "Options:"
	@echo "  V=1                 - Verbose output (show full assembler messages)"
	@echo "  VASM_HOME=/opt/vbcc - vasm installation path"
	@echo ""
	@echo "Documentation targets:"
	@echo "  guide / guides - Generate AmigaGuide documentation"
	@echo ""
	@echo "Dependency targets:"
	@echo "  ptable-sync    - Move $(PTABLE) to its upstream tip and rebuild (uncommitted)"
	@echo ""
	@echo "Release targets:"
	@echo "  version-readme - Update current release notes in docs/changes.md"
	@echo "  readme         - Generate $(README_NAME) from template"
	@echo "  release        - Create Aminet LHA archive + readme"
	@echo ""
	@echo "Utility targets:"
	@echo "  clean     - Remove built files"
	@echo "  distclean - Remove all generated files including readme"
	@echo "  help      - Show this help"
	@echo ""
	@echo "Output files:"
	@echo "  $(TARGET_080) - fat95 handler, Apollo 68080 tier (v$(FAT95_VERSION))"
	@echo "  $(TARGET_020) - fat95 handler, 68020+ tier (v$(FAT95_VERSION))"
	@echo "  $(TARGET_000) - fat95 handler, 68000 tier (v$(FAT95_VERSION))"
	@echo "  $(TARGET_INSTALL95) - install95 tool (v$(INSTALL95_VERSION))"
	@echo "  $(TARGET_DD) - dd tool (v$(DD_VERSION))"
	@echo "  $(TARGET_DEBUG95) - debug95 tool (v$(DEBUG95_VERSION))"
	@echo "  $(TARGET_SETFILESIZE) - SetFileSize tool (v$(SETFILESIZE_VERSION))"
	@echo "  $(TARGET_BOOT95) - boot95 tool (v$(BOOT95_VERSION))"
	@echo "  $(TARGET_LSFSRES) - lsfsres tool (v$(LSFSRES_VERSION))"
	@echo "  $(README_NAME) - Aminet readme"
	@echo "  $(ARCHIVE_NAME) - Aminet release archive"
	@echo ""
	@echo "Release: $(VERSION) ($(DATE)); fat95: $(FAT95_VERSION) ($(FAT95_DATE))"

# ============================================================
# Documentation targets
# ============================================================

# Generate AmigaGuide documentation from Markdown
GUIDE_OUTPUT_DIR = dist/docs
GUIDE_FAT95      = $(GUIDE_OUTPUT_DIR)/fat95.guide
GUIDE_CHANGES    = $(GUIDE_OUTPUT_DIR)/changes.guide
GUIDE_DD         = $(GUIDE_OUTPUT_DIR)/dd.guide
GUIDE_LSFSRES    = $(GUIDE_OUTPUT_DIR)/lsfsres.guide
GUIDE_LSPTRES    = $(GUIDE_OUTPUT_DIR)/lsptres.guide
MD2GUIDE = ../cfd/tools/md2guide.py

guide guides: $(GUIDE_FAT95) $(GUIDE_CHANGES) $(GUIDE_DD) $(GUIDE_LSFSRES)

$(GUIDE_FAT95): README.md $(MD2GUIDE)
	$(Q)mkdir -p $(GUIDE_OUTPUT_DIR)
	$(Q)echo "  GUIDE   $@"
	$(Q)python3 $(MD2GUIDE) README.md $@ --version $(VERSION) --date $(DATE) --title "fat95" --ver-title "fat95 guide"

$(GUIDE_CHANGES): docs/changes.md $(MD2GUIDE)
	$(Q)mkdir -p $(GUIDE_OUTPUT_DIR)
	$(Q)echo "  GUIDE   $@"
	$(Q)python3 $(MD2GUIDE) docs/changes.md $@ --version $(VERSION) --date $(DATE) --title "fat95 release notes" --ver-title "fat95 release notes guide"

$(GUIDE_DD): docs/dd.md $(MD2GUIDE)
	$(Q)mkdir -p $(GUIDE_OUTPUT_DIR)
	$(Q)echo "  GUIDE   $@"
	$(Q)python3 $(MD2GUIDE) docs/dd.md $@ --version $(DD_VERSION) --date $(DD_DATE) --title "dd" --ver-title "dd guide"

$(GUIDE_LSFSRES): docs/lsfsres.md $(MD2GUIDE)
	$(Q)mkdir -p $(GUIDE_OUTPUT_DIR)
	$(Q)echo "  GUIDE   $@"
	$(Q)python3 $(MD2GUIDE) docs/lsfsres.md $@ --version $(LSFSRES_VERSION) --date $(LSFSRES_DATE) --title "lsfsres" --ver-title "lsfsres guide"

.PHONY: all fat95 fat95-080 fat95-020 fat95-000 install95 dd debug95 setfilesize boot95 lsfsres clean distclean readme release check-vasm check-lha guide guides help version-readme FORCE
