#!/bin/bash
# TWRP kernel for LG G4 build script by jcadduono

################### BEFORE STARTING ################
#
# download a working toolchain and extract it somewhere and configure this
# file to point to the toolchain's root directory.
#
# once you've set up the config section how you like it, you can simply run
# ./build.sh [VARIANT]
#
##################### VARIANTS #####################
#
# h815  = International (Global)
#         LGH815  (LG G4)
#
# h811  = T-Mobile (USA)
#         LGH811  (LG G4)
#
###################### CONFIG ######################

# root directory of NetHunter G4 git repo (default is this script's location)
RDIR=$(pwd)

[ "$VER" ] ||
# version number
VER=$(cat "$RDIR/VERSION")

# directory containing cross-compile arm64 toolchain
TOOLCHAIN=$HOME/build/toolchain/gcc-linaro-4.9-2016.02-x86_64_aarch64-linux-gnu

# amount of cpu threads to use in kernel make process
THREADS=5

############## SCARY NO-TOUCHY STUFF ###############

export ARCH=arm64
export CROSS_COMPILE=$TOOLCHAIN/bin/aarch64-linux-gnu-

[ "$TARGET" ] || TARGET=twrp
[ "$1" ] && {
	VARIANT=$1
} || {
	VARIANT=h815
}
[ "$DEBUG" ] && {
	EXTRA_DEFCONFIG=debug_defconfig
} || {
	EXTRA_DEFCONFIG=
}
DEFCONFIG=${TARGET}_defconfig
VARIANT_DEFCONFIG=variant_${VARIANT}_defconfig

[ -f "$RDIR/arch/$ARCH/configs/$DEFCONFIG" ] || {
	echo "Config $DEFCONFIG not found in $ARCH configs!"
	exit 1
}

[ -f "$RDIR/arch/$ARCH/configs/$VARIANT_DEFCONFIG" ] || {
	echo "Variant $VARIANT not found in $ARCH configs!"
	exit 1
}

export LOCALVERSION="$TARGET-$VARIANT-$VER"
KDIR=$RDIR/build/arch/$ARCH/boot

ABORT()
{
	echo "Error: $*"
	exit 1
}

CLEAN_BUILD()
{
	echo "Cleaning build..."
	cd "$RDIR"
	rm -rf build
}

SETUP_BUILD()
{
	echo "Creating kernel config for $LOCALVERSION..."
	cd "$RDIR"
	mkdir -p build
	make -C "$RDIR" O=build "$DEFCONFIG" \
		VARIANT_DEFCONFIG="$VARIANT_DEFCONFIG" \
		EXTRA_DEFCONFIG="$EXTRA_DEFCONFIG" || ABORT "Failed to set up build"
}

BUILD_KERNEL()
{
	echo "Starting build for $LOCALVERSION..."
	while ! make -C "$RDIR" O=build -j"$THREADS"; do
		read -p "Build failed. Retry? " do_retry
		case $do_retry in
			Y|y) continue ;;
			*) return 1 ;;
		esac
	done
}

BUILD_DTB()
{
	echo "Generating dtb.img..."
	cd "$RDIR"
	scripts/dtbTool/dtbTool -o "$KDIR/dtb.img" "$KDIR/" -s 4096 || ABORT "Failed to generate dtb.img!"
}

CLEAN_BUILD && SETUP_BUILD && BUILD_KERNEL && BUILD_DTB && echo "Finished building $LOCALVERSION!"
