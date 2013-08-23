#!/bin/bash

# What we're building with
[ -z "$BINUTILS" ] && BINUTILS=2.23;
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

ARG_APPLY_PATCH=yes;

# Set locales to avoid python warnings
export LC_ALL=C;

# Set cache compression
export USE_CCACHE=1;
export CCACHE_DIR=$SOURCE/.ccache;


# Apply AOSP specific patches to upstream gcc
if [ "x${ARG_APPLY_PATCH}" = "xyes" ]; then
  sub_gcc_ver="`echo ${GCC} | grep -o '4\.\([5-9]\|[1-9][0-9]\)'`"
  echo "Will apply patches in gcc-patches/${sub_gcc_ver}"
  cd ${SOURCE}/gcc/gcc-${GCC} &&
  for FILE in `ls ${SOURCE}/gcc-patches/${sub_gcc_ver} 2>/dev/null` ; do
    if [ ! -f ${FILE}-patch.log ]; then
      echo "Apply patch: ${FILE}"
      git apply ${SOURCE}/gcc-patches/${sub_gcc_ver}/${FILE} 2>&1 | \
        tee "${FILE}-patch.log"
    fi
  done
fi

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
            --target=$TARGET \
            --enable-gold=default \
            --enable-graphite=yes \
            --disable-docs \
            --disable-nls \
            --with-pkgversion="axDev GCC"

make && make install && source generate-makefiles.sh;
