#!/bin/bash

# What we're building with
[ -z "$BINUTILS" ] && BINUTILS=upstream;
[ -z "$CLOOG" ] && CLOOG=0.18.0;
[ -z "$PPL" ] && PPL=1.0.x;
[ -z "$GCC" ] && GCC=4.8;
[ -z "$GDB" ] && GDB=7.6;
[ -z "$GMP" ] && GMP=5.1.2;
[ -z "$MPFR" ] && MPFR=3.1.2;
[ -z "$MPC" ] && MPC=1.0.1;
[ -z "$ISL" ] && ISL=0.12.1;
[ -z "$SYSROOT" ] && SYSROOT="/";

# Allow for building arm-eabi triplet
if [[ "x$1" = "xarm-eabi" ]]; then
    TARGET=arm-eabi;
else
    TARGET=arm-linux-androideabi;
fi

SOURCE=/media/root/Toshiba/Sources/aosp-toolchain;
DEST=/tmp/$TARGET-$GCC;

# Set locales to avoid python warnings
export LC_ALL=C;

# Set cache compression
export USE_CCACHE=1;
export CCACHE_DIR=$SOURCE/.ccache;


# Apply AOSP specific patches to binutils and gcc
cd $SOURCE/binutils/binutils-$BINUTILS && git add . && git reset --hard --quiet;
patch -N -p1 --reject-file=- < $SOURCE/build/binutils-$BINUTILS-android.patch;

cd $SOURCE/gcc/gcc-$GCC && git add . && git reset --hard --quiet;
patch -N -p1 --reject-file=- < $SOURCE/build/gcc-$GCC-android.patch;

# Remove existing output dir
if [ -d $DEST ];then rm -rf $DEST; fi

# Auto update GCC date stamp
echo $(date -u +%Y%m%d) > $SOURCE/gcc/gcc-$GCC/gcc/DATESTAMP;

# Start the build
cd $SOURCE/build &&
./configure \
            --prefix="$DEST" \
            --with-mpc-version="$MPC" \
            --with-gdb-version="$GDB" \
            --with-cloog-version="$CLOOG" \
            --with-ppl-version="$PPL" \
            --with-mpfr-version="$MPFR" \
            --with-isl-version="$ISL" \
            --with-gmp-version="$GMP" \
            --with-binutils-version="$BINUTILS" \
            --with-gold-version="$BINUTILS" \
            --with-gcc-version="$GCC" \
            --with-sysroot=$SYSROOT \
            --with-tune=cortex-a9 \
            --target=$TARGET \
            --enable-graphite=yes \
            --disable-docs \
            --disable-nls \
            --with-pkgversion="axDev GCC"

make && make install;
