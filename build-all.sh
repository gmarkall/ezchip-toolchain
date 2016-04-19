#! /bin/bash

TOOLCHAIN_DIR=$(cd "`dirname \"$0\"`"; pwd)
TOP=$(cd ${TOOLCHAIN_DIR}/..; pwd)

TARGET_TRIPLET=arceb-mellanox-linux-uclibc

echo "        Top: ${TOP}"
echo "  Toolchain: ${TOOLCHAIN_DIR}"
echo "     Target: ${TARGET_TRIPLET}"

# ====================================================================

BUILD_DIR=${TOP}/build
INSTALL_DIR=${TOP}/install
JOBS=
LOAD=

# ====================================================================

# Parse options
until
opt=$1
case ${opt} in
    --build-dir)
	shift
	BUILD_DIR=$(realpath -m $1)
	;;

    --install-dir)
	shift
	INSTALL_DIR=$(realpath -m $1)
	;;

    --jobs)
	shift
	JOBS=$1
	;;

    --load)
	shift
	LOAD=$1
	;;

    --single-thread)
	JOBS=1
	LOAD=1000
	;;

    ?*)
	echo "Unknown argument $1"
	echo
	echo "Usage: ./build-all.sh [--build-dir <build_dir>]"
        echo "                      [--install-dir <install_dir>]"
	echo "                      [--jobs <count>] [--load <load>]"
        echo "                      [--single-thread]"
	exit 1
	;;

    *)
	;;
esac
[ "x${opt}" = "x" ]
do
    shift
done

# ====================================================================

echo "  Build Dir: ${BUILD_DIR}"
echo "Install Dir: ${INSTALL_DIR}"


BINUTILS_BUILD_DIR=${BUILD_DIR}/binutils
GCC_STAGE_1_BUILD_DIR=${BUILD_DIR}/gcc-stage-1
GCC_STAGE_2_BUILD_DIR=${BUILD_DIR}/gcc-stage-2
LINUX_BUILD_DIR=${BUILD_DIR}/linux
UCLIBC_BUILD_DIR=${BUILD_DIR}/uClibc
GMP_BUILD_DIR=${BUILD_DIR}/gmp
MPC_BUILD_DIR=${BUILD_DIR}/mpc
MPFR_BUILD_DIR=${BUILD_DIR}/mpfr

INSTALL_PREFIX_DIR=${INSTALL_DIR}/usr
INSTALL_SYSCONF_DIR=${INSTALL_DIR}/etc
INSTALL_LOCALSTATE_DIR=${INSTALL_DIR}/var

SYSROOT_DIR=${INSTALL_DIR}/${TARGET_TRIPLET}/sysroot
SYSROOT_HEADER_DIR=${SYSROOT_DIR}/usr

# Default parallellism
processor_count="`(echo processor; cat /proc/cpuinfo 2>/dev/null echo processor) \
           | grep -c processor`"
if [ -z "${JOBS}" ]; then JOBS=${processor_count}; fi
if [ -z "${LOAD}" ]; then LOAD=${processor_count}; fi
PARALLEL="-j ${JOBS} -l ${LOAD}"

JOB_START_TIME=
JOB_TITLE=

SCRIPT_START_TIME=`date -u +%s`

LOGDIR=${TOP}/logs
LOGFILE=${LOGDIR}/build-$(date -u +%F-%H%M).log

echo "   Log file: ${LOGFILE}"
echo "   Start at: "`date`
echo ""

rm -f ${LOGFILE}
if ! mkdir -p ${LOGDIR}
then
    echo "Failed to create log directory: ${LOGDIR}"
    exit 1
fi

if ! touch ${LOGFILE}
then
    echo "Failed to initialise logfile: ${LOGFILE}"
    exit 1
fi

# ====================================================================

function msg ()
{
    echo "$1" | tee -a ${LOGFILE}
}

function error ()
{
    SCRIPT_END_TIME=`date -u +%s`
    TIME_STR=`times_to_time_string ${SCRIPT_START_TIME} ${SCRIPT_END_TIME}`

    echo "!! $1" | tee -a ${LOGFILE}
    echo "All finished ${TIME_STR}." | tee -a ${LOGFILE}
    echo ""
    echo "See ${LOGFILE} for more details"

    exit 1
}

function times_to_time_string ()
{
    local START=$1
    local END=$2

    local TIME_TAKEN=$((END - START))
    local TIME_STR=""

    if [ ${TIME_TAKEN} -gt 0 ]
    then
        local MINS=$((TIME_TAKEN / 60))
        local SECS=$((TIME_TAKEN - (60 * MINS)))
        local MIN_STR=""
        local SEC_STR=""
        if [ ${MINS} -gt 1 ]
        then
            MIN_STR=" ${MINS} minutes"
        elif [ ${MINS} -eq 1 ]
        then
            MIN_STR=" ${MINS} minute"
        fi
        if [ ${SECS} -gt 1 ]
        then
            SEC_STR=" ${SECS} seconds"
        elif [ ${SECS} -eq 1 ]
        then
            SEC_STR=" ${SECS} second"
        fi

        TIME_STR="in${MIN_STR}${SEC_STR}"
    else
        TIME_STR="instantly"
    fi

    echo "${TIME_STR}"
}

function job_start ()
{
    JOB_TITLE=$1
    JOB_START_TIME=`date -u +%s`
    echo "Starting: ${JOB_TITLE}" >> ${LOGFILE}
    echo -n ${JOB_TITLE}"..."
}

function job_done ()
{
    local JOB_END_TIME=`date -u +%s`
    local TIME_STR=`times_to_time_string ${JOB_START_TIME} ${JOB_END_TIME}`

    echo "Finished ${TIME_STR}." >> ${LOGFILE}
    echo -e "\r${JOB_TITLE} completed ${TIME_STR}."

    JOB_TITLE=""
    JOB_START_TIME=0
}

function mkdir_and_enter ()
{
    DIR=$1

    if ! mkdir -p ${DIR} >> ${LOGFILE} 2>&1
    then
       error "Failed to create directory: ${DIR}"
    fi

    if ! cd ${DIR} >> ${LOGFILE} 2>&1
    then
       error "Failed to entry directory: ${DIR}"
    fi
}

function run_command ()
{
    echo "" >> ${LOGFILE}
    echo "Current directory: ${PWD}" >> ${LOGFILE}
    echo -n "Running: " >> ${LOGFILE}
    for P in "$@"
    do
        V=`echo ${P} | sed -e 's/"/\\\\"/g'`
        echo -n "\"${V}\" " >> ${LOGFILE}
    done
    echo "" >> ${LOGFILE}
    echo "" >> ${LOGFILE}

    "$@" >> ${LOGFILE} 2>&1
    return $?
}

# ====================================================================
#                   Build and install binutils
# ====================================================================

job_start "Building binutils"

mkdir_and_enter "${BINUTILS_BUILD_DIR}"

if ! run_command ${TOP}/binutils-nps/configure \
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
then
    error "Failed to configure binutils"
fi

if ! run_command make ${PARALLEL}
then
    error "Failed to build binutils"
fi

if ! run_command make ${PARALLEL} install
then
    error "Failed to install binutils"
fi

job_done

# ====================================================================
#                      Install Linux headers
# ====================================================================

job_start "Installing Linux header files"

if ! run_command mkdir -p ${LINUX_BUILD_DIR}
then
    error "Failed to make linux build directory"
fi

if ! run_command cd ${TOP}/linux-nps
then
    error "Failed to entry linux source directory"
fi

# The following will fail if linux has already been configured.
if ! run_command make ${PARALLEL} ARCH=arc defconfig O="${LINUX_BUILD_DIR}"
then
    error "Failed to configure Linux headers directory"
fi

if ! run_command make ${PARALLEL} ARCH=arc INSTALL_HDR_PATH="${SYSROOT_HEADER_DIR}" headers_install
then
    error "Failed to install linux headers"
fi

job_done

# ====================================================================
#                     Install uClibc Headers
# ====================================================================

job_start "Install uClibc headers"

mkdir_and_enter "${UCLIBC_BUILD_DIR}"

if [ ! -f Makefile.in ]
then
    if ! tar -C "${TOP}"/uClibc-nps --exclude=.svn --exclude='*.o' \
	 --exclude='*.a' -cf - . | tar -xf -
    then
        error "Failed to copy uClibc sources across"
    fi

    if ! run_command cp ${TOOLCHAIN_DIR}/ezchip_nps_defconfig ${UCLIBC_BUILD_DIR}/extra/Configs/defconfigs/arc/
    then
        error "Failed to copy defconfig into uClibc directory"
    fi

    if ! sed -e "s#%KERNEL_HEADERS%#${SYSROOT_DIR}/usr/include#" \
             -e "s#%CROSS_COMPILER_PREFIX%#${INSTALL_PREFIX_DIR}/bin/${TARGET_TRIPLET}-#" \
             -i ${UCLIBC_BUILD_DIR}/extra/Configs/defconfigs/arc/ezchip_nps_defconfig
    then
        error "Failed to patch uClibc defconfig using sed"
    fi
fi

if ! run_command make distclean
then
    error "Failed to distclean in uClibc directory"
fi

if ! run_command make ARCH=arc ezchip_nps_defconfig
then
    error "Failed to setup .config in uClibc directory"
fi

if ! run_command make PREFIX="${SYSROOT_DIR}" install_headers
then
    error "Failed to install uClibc header files"
fi

job_done

# ====================================================================
#                Build and Install GCC (Stage 1)
# ====================================================================

job_start "Building stage 1 GCC"

mkdir_and_enter ${GCC_STAGE_1_BUILD_DIR}

if ! run_command ${TOP}/gcc-nps/configure \
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
then
    error "Failed to configure GCC (stage 1)"
fi

if ! run_command make ${PARALLEL} all-gcc all-target-libgcc
then
    error "Failed to build GCC (stage 1)"
fi

if ! run_command make ${PARALLEL} install-gcc install-target-libgcc
then
    error "Failed to install GCC (stage 1)"
fi

job_done

# ====================================================================
#                     Build and Install uClibc
# ====================================================================

job_start "Building full uClibc"

if ! run_command cd ${UCLIBC_BUILD_DIR}
then
    error "Failed to entry build uClibc directory"
fi

if ! run_command make clean
then
    error "Failed to clean uClibc build directory"
fi

if ! run_command make ${PARALLEL} PREFIX="${SYSROOT_DIR}"
then
    error "Failed to build uClibc"
fi

if ! run_command make ${PARALLEL} PREFIX="${SYSROOT_DIR}" install
then
    error "Failed to install uClibc"
fi

job_done

# ====================================================================
#                 Build and Install gmp package
# ====================================================================

job_start "Building gmp package"

mkdir_and_enter ${GMP_BUILD_DIR}

if ! run_command ${TOP}/gmp-6.0.0/configure --prefix="${INSTALL_PREFIX_DIR}" \
         --sysconfdir="${INSTALL_SYSCONF_DIR}" \
         --localstatedir="${INSTALL_LOCALSTATE_DIR}" \
         --with-sysroot="${SYSROOT_DIR}"
then
    error "Failed to configure gmp"
fi

if ! run_command make ${PARALLEL}
then
    error "Failed to build gmp"
fi

if ! run_command make ${PARALLEL} install
then
    error "Failed to install gmp"
fi

job_done

# ====================================================================
#                 Build and Install mpc package
# ====================================================================

job_start "Building mpc package"

mkdir_and_enter ${MPC_BUILD_DIR}

if ! run_command ${TOP}/mpc-1.0.3/configure --prefix="${INSTALL_PREFIX_DIR}" \
         --sysconfdir="${INSTALL_SYSCONF_DIR}" \
         --localstatedir="${INSTALL_LOCALSTATE_DIR}" \
         --with-sysroot="${SYSROOT_DIR}"
then
    error "Failed to configure mpc"
fi

if ! run_command make ${PARALLEL}
then
    error "Failed to build mpc"
fi

if ! run_command make ${PARALLEL} install
then
    error "Failed to install mpc"
fi

job_done

# ====================================================================
#                 Build and Install mpfr package
# ====================================================================

job_start "Building mpft package"

mkdir_and_enter ${MPFR_BUILD_DIR}

if ! run_command ${TOP}/mpfr-3.1.2/configure --prefix="${INSTALL_PREFIX_DIR}" \
         --sysconfdir="${INSTALL_SYSCONF_DIR}" \
         --localstatedir="${INSTALL_LOCALSTATE_DIR}" \
         --with-sysroot="${SYSROOT_DIR}"
then
    error "Failed to configure mpfr"
fi

if ! run_command make ${PARALLEL}
then
    error "Failed to build mpfr"
fi

if ! run_command make ${PARALLEL} install
then
    error "Failed to install mpfr"
fi

job_done

# ====================================================================
#                Build and Install GCC (stage 2)
# ====================================================================

job_start "Building stage 2 GCC"

mkdir_and_enter ${GCC_STAGE_2_BUILD_DIR}

if ! run_command ${TOP}/gcc-nps/configure --prefix="${INSTALL_PREFIX_DIR}" \
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
then
    error "Failed to configure GCC (stage 2)"
fi

if ! run_command make ${PARALLEL} all-gcc all-target-libgcc
then
    error "Failed to build GCC (stage 2)"
fi

if ! run_command make ${PARALLEL} install-gcc install-target-libgcc
then
    error "Failed to install GCC (stage 2)"
fi

job_done

# ====================================================================
#                           Finished
# ====================================================================

SCRIPT_END_TIME=`date -u +%s`
TIME_STR=`times_to_time_string ${SCRIPT_START_TIME} ${SCRIPT_END_TIME}`
echo "All finished ${TIME_STR}." | tee -a ${LOGFILE}
