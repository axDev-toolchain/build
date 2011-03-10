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

usage() {
  echo "--------------------------------------------------------------------"
  echo "--prefix=           Specify where to install (default: /tmp/android-toolchain-eabi)"
  echo "--toolchain-src=    Specify Android toolchain source dir (default: <toolchain/build>/../)"
  echo "--with-gcc=         Specify GCC source (support: directory, bzr, url)"
  echo "--apply-gcc-patch=(yes|no)   Apply gcc-patches (default: no)"
  echo "--help              Print help message"
  echo "--------------------------------------------------------------------"
}

ARG_LINARO_GCC_SRC_DIR=


downloadFormBZR() {
  local MY_LP_LINARO_GCC=$1
  ARG_LINARO_GCC_SRC_DIR=${MY_LP_LINARO_GCC#*:}

  [ ! -d ${ARG_TOOLCHAIN_SRC_DIR}/gcc ] && mkdir -p "${ARG_TOOLCHAIN_SRC_DIR}/gcc"
  if [ ! -d "${ARG_TOOLCHAIN_SRC_DIR}/gcc/${ARG_LINARO_GCC_SRC_DIR}" ]; then
    info "Use bzr to clone ${MY_LP_LINARO_GCC}"
    RUN=`bzr clone ${MY_LP_LINARO_GCC} ${ARG_TOOLCHAIN_SRC_DIR}/gcc/${ARG_LINARO_GCC_SRC_DIR}`
    [ $? -ne 0 ] && error "bzr ${MY_LP_LINARO_GCC} error"
  else
    info "${ARG_TOOLCHAIN_SRC_DIR}/gcc/${ARG_LINARO_GCC_SRC_DIR} is already exist, skip bzr clone"
  fi
}

downloadFormHTTP() {
  info "Use wget to get $1"
  local MY_LINARO_GCC_FILE=`basename $1`
  if [ -f "${MY_LINARO_GCC_FILE}" ]; then
    #TODO: Add md5 check
    info "${MY_LINARO_GCC_FILE} is already exist, skip download"
  else
    RUN=`wget $1`
    [ $? -ne 0 ] && error "wget $1 error"
    #TODO: Add md5 check
  fi

  ARG_LINARO_GCC_SRC_DIR=`basename ${MY_LINARO_GCC_FILE} .tar.bz2`
  [ ! -d ${ARG_TOOLCHAIN_SRC_DIR}/gcc ] && mkdir -p "${ARG_TOOLCHAIN_SRC_DIR}/gcc"
  if [ ! -d "${ARG_TOOLCHAIN_SRC_DIR}/gcc/${ARG_LINARO_GCC_SRC_DIR}" ]; then
    info "untar ${MY_LINARO_GCC_FILE} to ${ARG_TOOLCHAIN_SRC_DIR}/gcc"
    tar jxf ${MY_LINARO_GCC_FILE} -C ${ARG_TOOLCHAIN_SRC_DIR}/gcc
  else
    info "${ARG_TOOLCHAIN_SRC_DIR}/gcc/${ARG_LINARO_GCC_SRC_DIR} is already exist, skip untar"
  fi
}

getGCCFrom() {
  # set empty to detect error
  ARG_LINARO_GCC_SRC_DIR=
  ARG_LINARO_GCC_VER=

  case $1 in
    lp:*) # bzr clone lp:gcc-linaro
      downloadFormBZR $1
      ;;
    http://*) # snapshot URL: http://launchpad.net/gcc-linaro/4.5/4.5-2011.03-0/+download/gcc-linaro-4.5-2011.03-0.tar.bz2
      downloadFormHTTP $1
      ;;
    *) # local directory
      [ ! -d "${ARG_TOOLCHAIN_SRC_DIR}/gcc/$1" ] && error "$ARG_TOOLCHAIN_SRC_DIR/gcc/$ARG_LINARO_GCC_SRC_DIR not exist"
      ARG_LINARO_GCC_SRC_DIR=$1
  esac

  ARG_LINARO_GCC_VER=`echo ${ARG_LINARO_GCC_SRC_DIR} | grep -o "4\.[5-9]"`
  if [ ${ARG_LINARO_GCC_VER} = "" ]; then
    warn "Cannot detect version for ${ARG_LINARO_GCC_VER}, 4.5 is used"
    ARG_LINARO_GCC_VER=4.5
  fi
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

if [ "${ARG_TOOLCHAIN_SRC_DIR}" = "" ] || [ ! -f "${ARG_TOOLCHAIN_SRC_DIR}/build/configure" ] ; then
  error "--toolchain-src-dir is not set or ${ARG_TOOLCHAIN_SRC_DIR} is not ANDROID_TOOLCHAIN_ROOT"
fi

if [ "${ARG_WITH_GCC}" = "" ]; then
  error "Must specify --with-gcc to build toolchain"
fi

getGCCFrom $ARG_WITH_GCC

if [ "x${ARG_APPLY_PATCH}" = "xyes" ]; then
  note "Will apply patches in toolchain/gcc-patches/${ARG_LINARO_GCC_VER}"
  cd ${ARG_TOOLCHAIN_SRC_DIR}/gcc/${ARG_LINARO_GCC_SRC_DIR}
  for FILE in `ls ${ARG_TOOLCHAIN_SRC_DIR}/gcc-patches/${ARG_LINARO_GCC_VER}` ; do
    if [ ! -f ${FILE}-patch.log ]; then
      note "Applying patch ${FILE}"
      git apply ${ARG_TOOLCHAIN_SRC_DIR}/gcc-patches/${ARG_LINARO_GCC_VER}/${FILE} 2>&1 | tee "${FILE}-patch.log"
    fi
  done
  cd -
fi


GCC_VARIANT=`basename ${ARG_LINARO_GCC_SRC_DIR}`
GCC_VARIANT=${GCC_VARIANT#gcc-*}

if echo "$BUILD_ARCH" | grep -q '64' ; then
  info "Use 64-bit Build Enviorment"
  BUILD_HOST=x86_64-linux-gnu
  CC="gcc -m32"
  CXX="g++ -m32"
else
  info "Use 32-bit Build Enviorment"
  BUILD_HOST=i686-unknown-linux-gnu
fi

${ARG_TOOLCHAIN_SRC_DIR}/build/configure \
  --prefix=${ARG_PREFIX_DIR} --target=arm-eabi \
  --disable-docs --disable-nls \
  --host=${BUILD_HOST} --build=${BUILD_HOST} \
  --with-gcc-version=${GCC_VARIANT} \
  --with-binutils-version=2.20.1 \
  --with-gmp-version=4.2.4 \
  --with-mpfr-version=2.4.1 \
  --with-gdb-version=7.1.x

make
make install
