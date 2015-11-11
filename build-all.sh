#! /bin/bash

TOOLCHAIN_DIR=$(cd "`dirname \"$0\"`"; pwd)
TOP=$(cd ${TOOLCHAIN_DIR}/..; pwd)

TARGET_TRIPLET=arceb-ezchip-linux-uclibc

echo "      Top: ${TOP}"
echo "Toolchain: ${TOOLCHAIN_DIR}"
echo "   Target: ${TARGET_TRIPLET}"

BUILD_DIR=${TOP}/build
BINUTILS_BUILD_DIR=${BUILD_DIR}/binutils
GCC_STAGE_1_BUILD_DIR=${BUILD_DIR}/gcc-stage-1
GCC_STAGE_2_BUILD_DIR=${BUILD_DIR}/gcc-stage-2
LINUX_BUILD_DIR=${BUILD_DIR}/linux
UCLIBC_BUILD_DIR=${BUILD_DIR}/uClibc
GMP_BUILD_DIR=${BUILD_DIR}/gmp
MPC_BUILD_DIR=${BUILD_DIR}/mpc
MPFR_BUILD_DIR=${BUILD_DIR}/mpfr

INSTALL_DIR=${TOP}/install

INSTALL_PREFIX_DIR=${INSTALL_DIR}/usr
INSTALL_SYSCONF_DIR=${INSTALL_DIR}/etc
INSTALL_LOCALSTATE_DIR=${INSTALL_DIR}/var

SYSROOT_DIR=${INSTALL_DIR}/${TARGET_TRIPLET}/sysroot
SYSROOT_HEADER_DIR=${SYSROOT_DIR}/usr

# Default parallellism
processor_count="`(echo processor; cat /proc/cpuinfo 2>/dev/null echo processor) \
           | grep -c processor`"
PARALLEL="-j ${processor_count} -l ${processor_count}"

# --------------------
# Binutils
mkdir -p ${BINUTILS_BUILD_DIR}
cd ${BINUTILS_BUILD_DIR}
${TOP}/binutils-nps/configure \
    --prefix=${INSTALL_PREFIX_DIR} \
    --sysconfdir=${INSTALL_SYSCONF_DIR} \
    --localstatedir=${INSTALL_LOCALSTATE_DIR} \
    --enable-shared \
    --disable-static \
    --disable-gtk-doc \
    --disable-gtk-doc-html \
    --disable-doc \
    --disable-docs \
    --disable-documentation \
    --disable-debug \
    --with-xmlto=no \
    --with-fop=no \
    --disable-dependency-tracking \
    --disable-multilib \
    --disable-werror \
    --target=${TARGET_TRIPLET} \
    --disable-shared \
    --enable-static \
    --with-sysroot=${SYSROOT_DIR} \
    --enable-poison-system-directories \
    --disable-sim \
    --disable-gdb

make ${PARALLEL}
make ${PARALLEL} install

# --------------------
# Linux Headers
mkdir -p ${LINUX_BUILD_DIR}
cd ${TOP}/linux-nps
# The following will fail if linux has already been configured.
make ${PARALLEL} ARCH=arc defconfig O="${LINUX_BUILD_DIR}"
make ${PARALLEL} ARCH=arc INSTALL_HDR_PATH="${SYSROOT_HEADER_DIR}" headers_install

# --------------------
# uClibc Headers
mkdir -p ${UCLIBC_BUILD_DIR}
cd ${UCLIBC_BUILD_DIR}
if [ ! -f Makefile.in ]
then
    echo Copying over uClibc sources
    tar -C "${TOP}"/uClibc-nps --exclude=.svn --exclude='*.o' \
	--exclude='*.a' -cf - . | tar -xf -
    cp ${TOOLCHAIN_DIR}/ezchip_nps_defconfig ${UCLIBC_BUILD_DIR}/extra/Configs/defconfigs/arc/

    sed -e "s#%KERNEL_HEADERS%#${SYSROOT_DIR}/usr/include#" \
        -e "s#%CROSS_COMPILER_PREFIX%#${INSTALL_PREFIX_DIR}/bin/${TARGET_TRIPLET}-#" \
        -i ${UCLIBC_BUILD_DIR}/extra/Configs/defconfigs/arc/ezchip_nps_defconfig
fi

make distclean
make ARCH=arc ezchip_nps_defconfig
make PREFIX="${SYSROOT_DIR}" install_headers

# --------------------
# GCC (Stage 1)
mkdir -p ${GCC_STAGE_1_BUILD_DIR}
cd ${GCC_STAGE_1_BUILD_DIR}
${TOP}/gcc-nps/configure \
    --prefix="${INSTALL_PREFIX_DIR}" \
    --sysconfdir="${INSTALL_SYSCONF_DIR}" \
    --localstatedir="${INSTALL_LOCALSTATE_DIR}" \
    --enable-shared \
    --disable-static \
    --disable-gtk-doc \
    --disable-gtk-doc-html \
    --disable-doc \
    --disable-docs \
    --disable-documentation \
    --disable-debug \
    --with-xmlto=no \
    --with-fop=no \
    --disable-dependency-tracking \
    --target=${TARGET_TRIPLET} \
    --with-sysroot=${SYSROOT_DIR} \
    --disable-__cxa_atexit \
    --with-gnu-ld \
    --disable-libssp \
    --disable-multilib \
    --enable-target-optspace \
    --disable-libsanitizer \
    --disable-tls \
    --disable-libmudflap \
    --enable-threads \
    --without-isl \
    --without-cloog \
    --disable-decimal-float \
    --with-cpu=arc700 \
    --enable-languages=c \
    --disable-shared \
    --without-headers \
    --disable-threads \
    --with-newlib \
    --disable-largefile \
    --disable-nls
make ${PARALLEL} all-gcc all-target-libgcc
make ${PARALLEL} install-gcc install-target-libgcc

# --------------------
# Build uClibc
cd ${UCLIBC_BUILD_DIR}
make clean
make ${PARALLEL} PREFIX="${SYSROOT_DIR}"
make ${PARALLEL} PREFIX="${SYSROOT_DIR}" install

# --------------------
# Build gmp
mkdir -p ${GMP_BUILD_DIR}
cd ${GMP_BUILD_DIR}
${TOP}/gmp-6.0.0/configure --prefix="${INSTALL_PREFIX_DIR}" \
                           --sysconfdir="${INSTALL_SYSCONF_DIR}" \
                           --localstatedir="${INSTALL_LOCALSTATE_DIR}" \
                           --with-sysroot="${SYSROOT_DIR}"
make ${PARALLEL}
make ${PARALLEL} install

# --------------------
# Build mpc
mkdir -p ${MPC_BUILD_DIR}
cd ${MPC_BUILD_DIR}
${TOP}/gmp-1.0.3/configure --prefix="${INSTALL_PREFIX_DIR}" \
                           --sysconfdir="${INSTALL_SYSCONF_DIR}" \
                           --localstatedir="${INSTALL_LOCALSTATE_DIR}" \
                           --with-sysroot="${SYSROOT_DIR}"
make ${PARALLEL}
make ${PARALLEL} install

# --------------------
# Build mpfr
mkdir -p ${MPFR_BUILD_DIR}
cd ${MPFR_BUILD_DIR}
${TOP}/mpfr-3.1.2/configure --prefix="${INSTALL_PREFIX_DIR}" \
                            --sysconfdir="${INSTALL_SYSCONF_DIR}" \
                            --localstatedir="${INSTALL_LOCALSTATE_DIR}" \
                            --with-sysroot="${SYSROOT_DIR}"
make ${PARALLEL}
make ${PARALLEL} install

# --------------------
# GCC (Stage 2)
mkdir -p ${GCC_STAGE_2_BUILD_DIR}
cd ${GCC_STAGE_2_BUILD_DIR}
${TOP}/gcc-nps/configure --prefix="${INSTALL_PREFIX_DIR}" \
      --sysconfdir="${INSTALL_SYSCONF_DIR}" \
      --localstatedir="${INSTALL_LOCALSTATE_DIR}" \
      --enable-shared \
      --disable-static \
      --disable-gtk-doc \
      --disable-gtk-doc-html \
      --disable-doc \
      --disable-docs \
      --disable-documentation \
      --disable-debug \
      --with-xmlto=no \
      --with-fop=no \
      --disable-dependency-tracking \
      --target=${TARGET_TRIPLET} \
      --with-sysroot=${SYSROOT_DIR} \
      --disable-__cxa_atexit \
      --with-gnu-ld \
      --disable-libssp \
      --disable-multilib \
      --enable-target-optspace \
      --disable-libsanitizer \
      --disable-tls \
      --disable-libmudflap \
      --enable-threads \
      --without-isl \
      --without-cloog \
      --disable-decimal-float \
      --with-cpu=arc700 \
      --enable-languages=c \
      --disable-shared \
      --disable-threads \
      --with-newlib \
      --disable-largefile \
      --disable-nls \
      --with-gmp=${INSTALL_PREFIX_DIR} \
      --with-mpfr=${INSTALL_PREFIX_DIR} \
      --with-mpc=${INSTALL_PREFIX_DIR}
make ${PARALLEL} all-gcc all-target-libgcc
make ${PARALLEL} install-gcc install-target-libgcc
