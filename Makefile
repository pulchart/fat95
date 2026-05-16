# Makefile for fat95 filesystem handler
#
# Usage: make [options] [target]
#   help - show detailed usage output

# Driver Version (update these for new releases)
VERSION_MAJOR = 3
VERSION_MINOR = 22
VERSION_SUFFIX =
DATE = 16.05.2026

# Tools versions
INSTALL95_VERSION_MAJOR = 3
INSTALL95_VERSION_MINOR = 19
INSTALL95_VERSION_SUFFIX =
INSTALL95_DATE = 25.01.2026

DD_VERSION_MAJOR = 1
DD_VERSION_MINOR = 05
DD_VERSION_SUFFIX =
DD_DATE = 25.01.2026

DEBUG95_VERSION_MAJOR = 3
DEBUG95_VERSION_MINOR = 19
DEBUG95_VERSION_SUFFIX =
DEBUG95_DATE = 25.01.2026

SETFILESIZE_VERSION_MAJOR = 1
SETFILESIZE_VERSION_MINOR = 1
SETFILESIZE_VERSION_SUFFIX =
SETFILESIZE_DATE = 25.01.2026

BOOT95_VERSION_MAJOR = 3
BOOT95_VERSION_MINOR = 19
BOOT95_VERSION_SUFFIX =
BOOT95_DATE = 25.01.2026

LSFSRES_VERSION_MAJOR = 1
LSFSRES_VERSION_MINOR = 0
LSFSRES_VERSION_SUFFIX =
LSFSRES_DATE = 16.05.2026

# Compact date for any suffix-based filename stamping (DD.MM.YYYY -> YYYYMMDD)
DATE_COMPACT = $(shell echo "$(DATE)" | awk -F'.' '{printf "%04d%02d%02d", $$3, $$2, $$1}')

# Derived version
VERSION = $(VERSION_MAJOR).$(VERSION_MINOR)$(VERSION_SUFFIX)
VERSION_NODOT = $(VERSION_MAJOR)$(VERSION_MINOR)
ifneq ($(VERSION_SUFFIX),)
VERSION_FILENAME = $(VERSION_MAJOR).$(VERSION_MINOR)$(VERSION_SUFFIX)$(DATE_COMPACT)
else
VERSION_FILENAME = $(VERSION_MAJOR).$(VERSION_MINOR)
endif

INSTALL95_VERSION = $(INSTALL95_VERSION_MAJOR).$(INSTALL95_VERSION_MINOR)$(INSTALL95_VERSION_SUFFIX)
DD_VERSION = $(DD_VERSION_MAJOR).$(DD_VERSION_MINOR)$(DD_VERSION_SUFFIX)
DEBUG95_VERSION = $(DEBUG95_VERSION_MAJOR).$(DEBUG95_VERSION_MINOR)$(DEBUG95_VERSION_SUFFIX)
SETFILESIZE_VERSION = $(SETFILESIZE_VERSION_MAJOR).$(SETFILESIZE_VERSION_MINOR)$(SETFILESIZE_VERSION_SUFFIX)
BOOT95_VERSION = $(BOOT95_VERSION_MAJOR).$(BOOT95_VERSION_MINOR)$(BOOT95_VERSION_SUFFIX)
LSFSRES_VERSION = $(LSFSRES_VERSION_MAJOR).$(LSFSRES_VERSION_MINOR)$(LSFSRES_VERSION_SUFFIX)

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
VASM_HOME = /opt/vasm
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
VASMCPU_020 = -m68020 -D__68020__=1
VASMCPU_000 = -m68000

# Directories
SRCDIR = src
OUTDIR = dist/l
OUTDIR_020 = $(OUTDIR)/68020
OUTDIR_000 = $(OUTDIR)/68000

# Files: Driver (two CPU tiers)
# 68020+ ships under l/68020/ (A1200 stock + 68020+ accelerators
# 030/040/060/080).  68000 ships under l/68000/ for stock A500/A600/
# A1000/A2000/CDTV.  Tools stay single-tier (68000) because they do
# no math hot-path work.
SOURCE = $(SRCDIR)/fat95.s
TARGET_020 = $(OUTDIR_020)/fat95
TARGET_000 = $(OUTDIR_000)/fat95
# TARGET retained as an alias for the 020+ binary for any downstream
# snippets that still reference it (e.g. tool-chain helpers).
TARGET = $(TARGET_020)
DRIVER_TARGETS = $(TARGET_020) $(TARGET_000)

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
RELEASE_NAME = fat95.v$(VERSION_FILENAME)
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
	$(Q)echo "$(VERSION) $(DATE)" > $(VERSION_STAMP).tmp
	$(Q)if ! cmp -s $(VERSION_STAMP).tmp $(VERSION_STAMP) 2>/dev/null; then \
		mv $(VERSION_STAMP).tmp $(VERSION_STAMP); \
	else \
		rm -f $(VERSION_STAMP).tmp; \
	fi

# Update version and date in README.md (in-place)
# Updates the "What's New" section header: ### 3.19 (DD.MM.YYYY)
version-readme:
	$(Q)sed -i 's/^### $(VERSION_MAJOR)\.$(VERSION_MINOR)[^ ]* ([0-9]\{2\}\.[0-9]\{2\}\.[0-9]\{4\})/### $(VERSION) ($(DATE))/' README.md
	$(Q)echo "  README  version updated to $(VERSION) ($(DATE))"

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
endef

# Generate version include files
# fat95 uses a custom rule to emit a CPU-tier tag ([68020] / [68000]) in
# the VERSION_STRING, selected at assembly time via `ifd __68020__`.
$(VERSION_FAT95_INC): $(VERSION_STAMP)
	$(Q)echo "  VERSION fat95 $(VERSION)" >&2
	$(Q)echo "; Auto-generated by Makefile." > $@
	$(Q)echo "FILE_VERSION	= $(VERSION_MAJOR)" >> $@
	$(Q)echo "FILE_REVISION	= $(VERSION_MINOR)" >> $@
	$(Q)echo "VERSION_STRING	macro" >> $@
	$(Q)echo "	ifd	__68020__" >> $@
	$(Q)echo "	dc.b	\"\$$VER: fat95 $(VERSION) ($(DATE)) [68020]\"" >> $@
	$(Q)echo "	else" >> $@
	$(Q)echo "	dc.b	\"\$$VER: fat95 $(VERSION) ($(DATE)) [68000]\"" >> $@
	$(Q)echo "	endc" >> $@
	$(Q)echo "	endm" >> $@

$(VERSION_INSTALL95_INC): $(VERSION_STAMP)
	$(call gen_version_inc,$@,install95,$(INSTALL95_VERSION_MAJOR),$(INSTALL95_VERSION_MINOR),$(INSTALL95_VERSION),VER_STRING,$(INSTALL95_DATE),1)

$(VERSION_DD_INC): $(VERSION_STAMP)
	$(call gen_version_inc,$@,dd,,,$(DD_VERSION),VER_STRING,$(DD_DATE),1)

$(VERSION_DEBUG95_INC): $(VERSION_STAMP)
	$(call gen_version_inc,$@,debug95,,,$(DEBUG95_VERSION),VER_STRING,$(DEBUG95_DATE),1)

$(VERSION_SETFILESIZE_INC): $(VERSION_STAMP)
	$(call gen_version_inc,$@,SetFileSize,,,$(SETFILESIZE_VERSION),VER_STRING,$(SETFILESIZE_DATE),1)

$(VERSION_BOOT95_INC): $(VERSION_STAMP)
	$(call gen_version_inc,$@,boot95,$(BOOT95_VERSION_MAJOR),$(BOOT95_VERSION_MINOR),$(BOOT95_VERSION),VER_STRING,$(BOOT95_DATE),1)

$(VERSION_LSFSRES_INC): $(VERSION_STAMP)
	$(call gen_version_inc,$@,lsfsres,,,$(LSFSRES_VERSION),VER_STRING,$(LSFSRES_DATE),1)

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
TOOLS = fat95_68020:$(TARGET_020):$(VERSION):$(DATE) \
	fat95_68000:$(TARGET_000):$(VERSION):$(DATE) \
	install95:$(TARGET_INSTALL95):$(INSTALL95_VERSION):$(INSTALL95_DATE) \
	dd:$(TARGET_DD):$(DD_VERSION):$(DD_DATE) \
	debug95:$(TARGET_DEBUG95):$(DEBUG95_VERSION):$(DEBUG95_DATE) \
	SetFileSize:$(TARGET_SETFILESIZE):$(SETFILESIZE_VERSION):$(SETFILESIZE_DATE) \
	boot95:$(TARGET_BOOT95):$(BOOT95_VERSION):$(BOOT95_DATE) \
	lsfsres:$(TARGET_LSFSRES):$(LSFSRES_VERSION):$(LSFSRES_DATE)
TOOLS_TARGETS = $(DRIVER_TARGETS) $(TARGET_INSTALL95) $(TARGET_DD) $(TARGET_DEBUG95) $(TARGET_SETFILESIZE) $(TARGET_BOOT95) $(TARGET_LSFSRES)

# Generate readme from template
$(README_NAME): $(README_TEMPLATE) $(TOOLS_TARGETS)
	@echo "Generating $(README_NAME) from template..."
	@# Generate checksum sections for all tools
	@tool_checksums=""; \
	for tool_info in $(TOOLS); do \
		tool_name=$$(echo $$tool_info | cut -d: -f1); \
		tool_target=$$(echo $$tool_info | cut -d: -f2); \
		tool_version=$$(echo $$tool_info | cut -d: -f3); \
		tool_date=$$(echo $$tool_info | cut -d: -f4); \
		if [ -f "$$tool_target" ]; then \
			tool_size=$$(stat -c%s "$$tool_target" 2>/dev/null || echo 0); \
			tool_md5=$$(md5sum "$$tool_target" 2>/dev/null | cut -d' ' -f1 || echo "N/A"); \
			tool_sha256=$$(sha256sum "$$tool_target" 2>/dev/null | cut -d' ' -f1 || echo "N/A"); \
			tool_checksums="$$tool_checksums$$tool_name $$tool_version ($$tool_date) ($$tool_size bytes):\n  MD5:    $$tool_md5\n  SHA256: $$tool_sha256\n\n"; \
		fi; \
	done; \
	sed -e "s|@VERSION@|$(VERSION)|g" \
		-e "s|@DATE@|$(DATE)|g" \
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
release: check-vasm version-readme all $(README_NAME) $(GUIDE_OUTPUT) check-lha
	@echo "Creating $(ARCHIVE_NAME)..."
	@S=$$(mktemp -d); \
	mkdir -p "$$S/fat95/l/68020" "$$S/fat95/l/68000" "$$S/fat95/c" "$$S/fat95/src"; \
	cp $(TARGET_020) "$$S/fat95/l/68020/"; \
	cp $(TARGET_000) "$$S/fat95/l/68000/"; \
	cp $(TARGET_INSTALL95) "$$S/fat95/l/"; \
	cp dist/c/* "$$S/fat95/c/"; \
	cp src/*.s src/*.i "$$S/fat95/src/"; \
	cp $(README_NAME) "$$S/fat95/fat95.readme"; \
	cp $(README_INFO) LICENSE $(GUIDE_OUTPUT) $(GUIDE_OUTPUT).info "$$S/fat95/"; \
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
	@echo "  guide   - Generate AmigaGuide from README.md"
	@echo ""
	@echo "Release targets:"
	@echo "  version-readme - Update version suffix in README.md (in-place)"
	@echo "  readme         - Generate $(README_NAME) from template"
	@echo "  release        - Create Aminet LHA archive + readme"
	@echo ""
	@echo "Utility targets:"
	@echo "  clean     - Remove built files"
	@echo "  distclean - Remove all generated files including readme"
	@echo "  help      - Show this help"
	@echo ""
	@echo "Output files:"
	@echo "  $(TARGET_020) - fat95 handler, 68020+ tier (v$(VERSION))"
	@echo "  $(TARGET_000) - fat95 handler, 68000 tier (v$(VERSION))"
	@echo "  $(TARGET_INSTALL95) - install95 tool (v$(INSTALL95_VERSION))"
	@echo "  $(TARGET_DD) - dd tool (v$(DD_VERSION))"
	@echo "  $(TARGET_DEBUG95) - debug95 tool (v$(DEBUG95_VERSION))"
	@echo "  $(TARGET_SETFILESIZE) - SetFileSize tool (v$(SETFILESIZE_VERSION))"
	@echo "  $(TARGET_BOOT95) - boot95 tool (v$(BOOT95_VERSION))"
	@echo "  $(TARGET_LSFSRES) - lsfsres tool (v$(LSFSRES_VERSION))"
	@echo "  $(README_NAME) - Aminet readme"
	@echo "  $(ARCHIVE_NAME) - Aminet release archive"
	@echo ""
	@echo "Version: $(VERSION) ($(DATE))"

# ============================================================
# Documentation targets
# ============================================================

# Generate AmigaGuide documentation from README.md
GUIDE_OUTPUT = dist/fat95.guide
MD2GUIDE = ../cfd/tools/md2guide.py

guide: $(GUIDE_OUTPUT)

$(GUIDE_OUTPUT): README.md $(MD2GUIDE)
	$(Q)echo "  GUIDE   $@"
	$(Q)python3 $(MD2GUIDE) README.md $@ --version $(VERSION) --date $(DATE) --title "fat95" --ver-title "fat95 guide"

.PHONY: all fat95 fat95-020 fat95-000 install95 dd debug95 setfilesize boot95 lsfsres clean distclean readme release check-vasm check-lha guide help version-readme FORCE
