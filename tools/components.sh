#!/bin/sh
# Emit the "components in this release" list, flagging each component
# whose version or date changed since the previous release tag.
#
# Usage:
#   tools/components.sh <md|plain> "PREFIX|name|version|date" ...
#
# Output is a single line with literal "\n" between bullets, ready for
# either GNU sed substitution (readme template) or awk -v (README.md);
# both turn "\n" into real newlines.
#
#   md     `name version (date)` _(new)_      (markdown, for README.md)
#   plain   name version (date) (new)         (plain text, for the .readme)
#
# Current versions are passed in by the Makefile (the source of truth).
# The previous release is read from that tag's Makefile via git; the
# "[$]" filter skips derived "X = $(Y)" lines so only literal source
# values are compared.
fmt=$1
shift

prev=$(git describe --tags --abbrev=0 --match 'v[0-9]*' --exclude '*-dev*' 2>/dev/null)
oldmk=$(git show "$prev:Makefile" 2>/dev/null)

# First literal (non-derived) value of a Makefile macro in the previous tag.
old_val() {
	printf '%s\n' "$oldmk" | sed -n "s/^$1[[:space:]]*=[[:space:]]*//p" | grep -v '[$]' | head -1
}

# Version string for prefix $1 as defined in the previous tag, tolerating
# the macro names this project has used over time: a single X_VERSION = 1.37
# line, or X_MAJOR/X_MINOR, or the older X_VERSION_MAJOR/X_VERSION_MINOR.
# Empty if that tag did not define the component (treated as new).
old_version() {
	v=$(old_val "${1}_VERSION")
	if [ -z "$v" ]; then
		maj=$(old_val "${1}_MAJOR"); [ -n "$maj" ] || maj=$(old_val "${1}_VERSION_MAJOR")
		min=$(old_val "${1}_MINOR"); [ -n "$min" ] || min=$(old_val "${1}_VERSION_MINOR")
		[ -n "$maj" ] && v="$maj.$min$(old_val "${1}_VERSION_SUFFIX")"
	fi
	printf '%s' "$v"
}

out=
sep=
for entry in "$@"; do
	prefix=${entry%%|*}; rest=${entry#*|}
	name=${rest%%|*};    rest=${rest#*|}
	ver=${rest%%|*};     date=${rest#*|}

	ov=$(old_version "$prefix")
	od=$(old_val "${prefix}_DATE")

	new=
	{ [ -z "$prev" ] || [ "$ver ($date)" != "$ov ($od)" ]; } && new=1

	if [ "$fmt" = md ]; then
		line="- \`$name $ver ($date)\`${new:+ _(new)_}"
	else
		line="- $name $ver ($date)${new:+ (new)}"
	fi

	out="$out$sep$line"
	sep='\n'
done

printf '%s' "$out"
