#!/bin/bash

SNAP_PROFILES_D="/etc/snapback.d"
SNAP_PROFILE=""
SNAP_DATE="`date '+%Y%m%d%H%M'`"
SNAP_DRY=0
SNAP_RARG=""
SNAP_LARG=""
SNAP_VERBOSE=0
SNAP_HELP=0

while [ "$1" ]; do
	case "$1" in
		-v)
			SNAP_VERBOSE=1
			SNAP_RARG="$SNAP_RARG -v"
			SNAP_LARG="$SNAP_LARG -v"
			;;

		-q)
			SNAP_VERBOSE=0
			SNAP_RARG="$SNAP_RARG -q"
			SNAP_LARG="$SNAP_LARG -q"
			;;

		-n)
			SNAP_DRY=1
			;;

		-p)
			shift
			SNAP_PROFILES_D="$1"
			;;

		-d)
			SNAP_RARG="$SNAP_RARG --delete"
			;;

		-h)
			SNAP_HELP=1
			;;

		*)
			SNAP_PROFILE="$1"
			;;
	esac
	shift
done

if [ $SNAP_HELP -eq 1 ] || [ -z "$SNAP_PROFILE" ]; then
	echo "usage: $0 [-q|-v] [-n] [-d] [-p <profiles_dir>] <profile>"
	echo
	echo "-q	Supress non-error messages."
	echo "-v	Show extra detail."
	echo "-d	Delete sender-deleted files on receiving side."
	echo "-n	Dry run."
	echo "-p	Read profiles from <profiles_dir>."
	exit 1
fi

# Get profile-specific config from profile.ini.

SNAP_VG="`grep "^vg=" "$SNAP_PROFILES_D/$SNAP_PROFILE.ini" | \
	sed 's/^vg=//g'`"
SNAP_NAME="`grep "^name=" "$SNAP_PROFILES_D/$SNAP_PROFILE.ini" | \
	sed 's/^name=//g' | sed "s/%date%/$SNAP_DATE/g"`"
SNAP_LV="`grep "^lv=" "$SNAP_PROFILES_D/$SNAP_PROFILE.ini" | \
	sed 's/^lv=//g'`"
SNAP_SZ="`grep "^sz=" "$SNAP_PROFILES_D/$SNAP_PROFILE.ini" | \
	sed 's/^sz=//g'`"
SNAP_RSYNC_DEST="`grep \
	"^rsync_dest=" "$SNAP_PROFILES_D/$SNAP_PROFILE.ini" | \
	sed 's/^rsync_dest=//g'`"
SNAP_RSYNC_SRC="`grep \
	"^rsync_src=" "$SNAP_PROFILES_D/$SNAP_PROFILE.ini" | \
	sed 's/^rsync_src=//g'`"
SNAP_MOUNT="`grep "^mount=" "$SNAP_PROFILES_D/$SNAP_PROFILE.ini" | \
	sed 's/^mount=//g'`"

# Utility functions.

snap_cleanup_abort() {
	if [ $SNAP_VERBOSE -ne 0 ]; then
		echo "cleaning up..."
	fi

	if grep "\s$SNAP_MOUNT" /proc/mounts >/dev/null; then
		if [ $SNAP_VERBOSE -ne 0 ]; then
			echo "unmounting $SNAP_MOUNT..."
		fi
		/bin/umount "$SNAP_MOUNT"
	fi

	if [ -b "/dev/$SNAP_VG/$SNAP_NAME" ]; then
		if [ $SNAP_VERBOSE -ne 0 ]; then
			echo "removing snapshot $SNAP_VG/$SNAP_NAME..."
		fi
		/sbin/lvremove$SNAP_LARG -f "/dev/$SNAP_VG/$SNAP_NAME"
	fi

}

# Main procedure.

if [ $SNAP_VERBOSE -ne 0 ]; then
	echo "creating $SNAP_SZ snapshot $SNAP_VG/$SNAP_NAME from $SNAP_VG/$SNAP_LV..."
fi
if [ $SNAP_DRY -eq 0 ]; then
	/sbin/lvcreate$SNAP_LARG --size "$SNAP_SZ" --name "$SNAP_NAME" \
		--snapshot "/dev/$SNAP_VG/$SNAP_LV" || \
	(snap_cleanup_abort; exit 1)
fi

if [ $SNAP_VERBOSE -ne 0 ]; then
	echo "mounting $SNAP_VG/$SNAP_NAME to $SNAP_MOUNT..."
fi
if [ $SNAP_DRY -eq 0 ]; then
	/bin/mount -o ro "/dev/$SNAP_VG/$SNAP_NAME" "$SNAP_MOUNT" || \
	(snap_cleanup_abort; exit 1)
fi

if [ $SNAP_VERBOSE -ne 0 ]; then
	echo "syncing $SNAP_RSYNC_SRC to $SNAP_RSYNC_DEST..."
fi
if [ $SNAP_DRY -eq 0 ]; then
	/usr/bin/rsync -az$SNAP_RARG "$SNAP_RSYNC_SRC" "$SNAP_RSYNC_DEST" || \
	(snap_cleanup_abort; exit 1)
fi

snap_cleanup_abort

