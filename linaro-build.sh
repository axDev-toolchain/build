#!/bin/bash

# Copyright (C) 2011 Linaro
#
# This file is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.

ARG_PREFIX_DIR=/tmp/android-toolchain-eabi
ARG_TOOLCHAIN_SRC_DIR=${PWD%/build}

ARG_LINARO_GCC_SRC_DIR=
ARG_WGET_LINARO_GCC_SRC=
ARG_BZR_LINARO_GCC_SRC=

ARG_WITH_GCC=
ARG_WITH_GDB=
ARG_WITH_SYSROOT=

ARG_APPLY_PATCH=no

abort() {
  echo $@
  exec false
}

error() {
  abort "[ERROR] $@"
}

warn() {
  echo "[WARNING] $@"
}

info() {
  echo "[INFO] $@"
}

note() {
  echo "[NOTE] $@"
}

PROGNAME=`basename $0`

usage() {
  echo "Usage: $PROGNAME [options]"
  echo
  echo "Valid options (defaults are in brackets)"
  echo "  --prefix=<path>             Specify installation path [/tmp/android-toolchain-eabi]"
  echo "  --toolchain-src=<path>      Toolchain source directory [`dirname $PWD`]"
  echo "  --with-gcc=<path>           Specify GCC source (support: directory, bzr, url)"
  echo "  --with-gdb=<path>           Specify gdb source (support: directory, bzr, url)"
  echo "  --with-sysroot=<path>       Specify SYSROOT directory"
  echo "  --apply-gcc-patch=<yes|no>  Apply Linaro's extra gcc-patches [no]"
  echo "  --help                      Print this help message"
  echo
}

# $1 - package name (gcc, gdb, etc)
# $2 - value of ARG_WITH_package (lp:*, http://*)
downloadFromBZR() {
  local package=$1
  local MY_LP_LINARO_PKG=$2
  local version=$3

  local PACKAGE_NAME=`echo $package | tr "[:lower:]" "[:upper:]"`
  eval "ARG_LINARO_${PACKAGE_NAME}_SRC_DIR=$package-$version"

  dir=${ARG_TOOLCHAIN_SRC_DIR}/$package/$package-$version
  if [ ! -d "$dir" ]; then
    info "Use bzr to clone ${MY_LP_LINARO_PKG}"
    echo bzr clone ${MY_LP_LINARO_PKG} $dir
    bzr clone ${MY_LP_LINARO_PKG} $dir
    [ $? -ne 0 ] && error "bzr ${MY_LP_LINARO_PKG} fails."
  else
    info "$dir already exists, doing bzr update"
    (cd $dir; bzr update)
  fi
}

# $1 - package name (gcc, gdb, etc)
# $2 - arg (lp:*, http://*)
downloadFromHTTP() {
  local package=$1
  local url=$2
  local file=`basename $url`

  local PACKAGE_NAME=`echo $package | tr "[:lower:]" "[:upper:]"`

  info "Use wget to get $file"
  if [ -f "${ARG_TOOLCHAIN_SRC_DIR}/$package/${file}" ]; then
    #TODO: Add md5 check
    info "${file} is already exist, skip download"
  else
    wget -c "$url" || error "wget $1 error"
    mv "$file" "${ARG_TOOLCHAIN_SRC_DIR}/$package/" || error "fail to move $file"
    #TODO: Add md5 check
  fi

  local src_dir=$(basename $file)
  src_dir=$(echo $src_dir | sed "s/\(\.tar\.bz2\|\.tar\.gz\|\.tgz\|\.tbz\)//")
  eval "ARG_LINARO_${PACKAGE_NAME}_SRC_DIR=${src_dir}"
}

# $1 - value of ARG_WITH_package
getPackage() {
  local package
  local version
  case $1 in
    lp:*)
      package=${1##lp:}
      version=${package#*-}
      # Replace / with -
      version=${version////-}
      package=${package%%-*}
      info "Detected package \"$package\" and version \"$version\" for $1 bzr repo"
      ;;
    *)
      package=$(basename $1)
      version=${package#*-}
      version=$(echo $version | sed "s/\(\.tar\.bz2\|\.tar\.gz\|\.tgz\|\.tbz\)//")
      package=${package%%-*}
      ;;
  esac

  local PACKAGE_NAME=`echo $package | tr "[:lower:]" "[:upper:]"`
  # Make sure that package dir exists
  mkdir -p ${ARG_TOOLCHAIN_SRC_DIR}/$package || error "Cannot create ${ARG_TOOLCHAIN_SRC_DIR}/$package directory"

  case $1 in
    lp:*) # bzr clone lp:gcc-linaro
      downloadFromBZR $package $1 $version
      ;;
    http://*) # snapshot URL
      # http://launchpad.net/gcc-linaro/4.5/4.5-2011.04-0/+download/gcc-linaro-4.5-2011.04-0.tar.bz2
      downloadFromHTTP $package $1
      ;;
    *) # local directory
      [ ! -d "${ARG_TOOLCHAIN_SRC_DIR}/$package/$1" ] && \
        echo "Directory $ARG_TOOLCHAIN_SRC_DIR/$package/$1 does not exist" && \
        mkdir -p $ARG_TOOLCHAIN_SRC_DIR/$package && \
        error "Please extract the $package source into directory $ARG_TOOLCHAIN_SRC_DIR/$package"
      eval "ARG_LINARO_${PACKAGE_NAME}_SRC_DIR=$1"
  esac

  # verify version
  case $package in
    gcc)
      # make sure version is greater than 4.5
      ver=`echo $version | grep -o "^4\.\([5-9]\|[1-9][0-9]\)"`
      if [ x"$version" = x"" ]; then
        warn "Cannot detect version for $package-$version, 4.5 is used"
        version="4.5"
      fi
      ;;
  esac

  eval "ARG_LINARO_${PACKAGE_NAME}_VER=$version"
}

while [ $# -gt 0 ]; do
  ARG=$1
  ARG_PARMS="$ARG_PARMS '$ARG'"
  shift
  case "$ARG" in
    --prefix=*)
      ARG_PREFIX_DIR="${ARG#*=}"
      ;;
    --toolchain-src=*)
      ARG_TOOLCHAIN_SRC_DIR="${ARG#*=}"
      ;;
    --with-gcc=*)
      ARG_WITH_GCC="${ARG#*=}"
      ;;
    --with-gdb=*)
      ARG_WITH_GDB="${ARG#*=}"
      ;;
    --with-sysroot=*)
      ARG_WITH_SYSROOT="${ARG#*=}"
      ;;
    --apply-gcc-patch=yes | --apply-gcc-patch=no)
      ARG_APPLY_PATCH="${ARG#*=}"
      ;;
    --help)
      usage && abort
      ;;
    *)
      error "Unrecognized parameter $ARG"
      ;;
  esac
done

BUILD_ARCH=`uname -m`
BUILD_WITH_LOCAL=
BUILD_HOST=
BUILD_SYSROOT=

if [ "${ARG_TOOLCHAIN_SRC_DIR}" = "" ] || [ ! -f "${ARG_TOOLCHAIN_SRC_DIR}/build/configure" ] ; then
  error "--toolchain-src-dir is not set or ${ARG_TOOLCHAIN_SRC_DIR} is not ANDROID_TOOLCHAIN_ROOT"
fi

if [ x"${ARG_WITH_GCC}" = x"" ]; then
  error "Must specify --with-gcc to build toolchain"
fi

if [ ! -z "${ARG_WITH_SYSROOT}" ]; then
  if [ ! -d "${ARG_WITH_SYSROOT}" ]; then
    error "SYSROOT ${ARG_WITH_SYSROOT} not exist"
  fi
  BUILD_SYSROOT="--with-sysroot=${ARG_WITH_SYSROOT}"
fi

for package in ${!ARG_WITH*}; do
  if [ x"${!package}" != "x" ]; then
    getPackage ${!package}
  fi
done

if [ "x${ARG_APPLY_PATCH}" = "xyes" ]; then
  sub_gcc_ver="`echo ${ARG_LINARO_GCC_VER} | grep -o '4\.\([5-9]\|[1-9][0-9]\)'`"
  note "Will apply patches in toolchain/gcc-patches/${sub_gcc_ver}"
  cd ${ARG_TOOLCHAIN_SRC_DIR}/gcc/${ARG_LINARO_GCC_SRC_DIR} &&
  for FILE in `ls ${ARG_TOOLCHAIN_SRC_DIR}/gcc-patches/${sub_gcc_ver} 2>/dev/null` ; do
    if [ ! -f ${FILE}-patch.log ]; then
      note "Apply patch: ${FILE}"
      git apply ${ARG_TOOLCHAIN_SRC_DIR}/gcc-patches/${sub_gcc_ver}/${FILE} 2>&1 | \
        tee "${FILE}-patch.log"
    fi
  done
  cd -
fi

if [ x"${ARG_WITH_GCC}" != x"" ]; then
  BUILD_WITH_GCC="--with-gcc-version=${ARG_LINARO_GCC_VER}"
fi

if [ x"${ARG_WITH_GDB}" != x"" ]; then
  BUILD_WITH_GDB="--with-gdb-version=${ARG_LINARO_GDB_VER}"
fi

if echo "$BUILD_ARCH" | grep -q '64' ; then
  info "Use 64-bit Build environment"
  BUILD_HOST=x86_64-linux-gnu
  ABI="32"
  CFLAGS="-m32"
  CXXFLAGS="-m32"
  LDFLAGS="-L/usr/lib32"
  export ABI CFLAGS CXXFLAGS LDFLAGS
else
  info "Use 32-bit Build environment"
  BUILD_HOST=i686-unknown-linux-gnu
fi

[ -z "$TARGET" ] && TARGET=arm-linux-androideabi

${ARG_TOOLCHAIN_SRC_DIR}/build/configure \
  --prefix=${ARG_PREFIX_DIR} --target=${TARGET} \
  --disable-docs --disable-nls \
  --host=${BUILD_HOST} --build=${BUILD_HOST} \
  ${BUILD_SYSROOT} \
  \
  ${BUILD_WITH_GCC} \
  ${BUILD_WITH_GDB} \
  --with-binutils-version=${BINUTILS_VERSION-2.23.51.0.3} \
  \
  --with-gmp-version=${GMP_VERSION-5.0.5} \
  --with-mpfr-version=${MPFR_VERSION-3.1.1} \
  --with-mpc-version=${MPC_VERSION-1.0} \
  \
  ${LINARO_BUILD_EXTRA_CONFIGURE_FLAGS}

make HOSTGCC="$HOSTGCC" && make install
