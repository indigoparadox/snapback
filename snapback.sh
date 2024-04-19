#!/bin/bash

SNAP_PROFILES_D="/etc/snapback.d"
SNAP_PROFILE="$1"
SNAP_DATE="`date '+%Y%m%d%H%M'`"
SNAP_DRY=0

if [ -z "$SNAP_PROFILE" ]; then
	echo "usage: $0 <profile>"
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
	echo "cleaning up..."

	if grep "\s$SNAP_MOUNT" /proc/mounts >/dev/null; then
		echo "unmounting $SNAP_MOUNT..."
		/bin/umount "$SNAP_MOUNT"
	fi

	if [ -b "/dev/$SNAP_VG/$SNAP_NAME" ]; then
		echo "removing snapshot $SNAP_VG/$SNAP_NAME..."
		/sbin/lvremove -f "/dev/$SNAP_VG/$SNAP_NAME"
	fi

}

# Main procedure.

echo "creating $SNAP_SZ snapshot $SNAP_VG/$SNAP_NAME from $SNAP_VG/$SNAP_LV..."
if [ $SNAP_DRY -eq 0 ]; then
	/sbin/lvcreate --size "$SNAP_SZ" --name "$SNAP_NAME" \
		--snapshot "/dev/$SNAP_VG/$SNAP_LV" || \
	(snap_cleanup_abort; exit 1)
fi

echo "mounting $SNAP_VG/$SNAP_NAME to $SNAP_MOUNT..."
if [ $SNAP_DRY -eq 0 ]; then
	/bin/mount -o ro "/dev/$SNAP_VG/$SNAP_NAME" "$SNAP_MOUNT" || \
	(snap_cleanup_abort; exit 1)
fi

echo "syncing $SNAP_RSYNC_SRC to $SNAP_RSYNC_DEST..."
if [ $SNAP_DRY -eq 0 ]; then
	/usr/bin/rsync -avz "$SNAP_RSYNC_SRC" "$SNAP_RSYNC_DEST" || \
	(snap_cleanup_abort; exit 1)
fi

snap_cleanup_abort

