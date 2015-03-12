#!/bin/bash

# udoo-arduino-build.sh
# written 2015 4commerce technologies AG, Tom Freudenberg
# derrived from due-arduino-build.sh by Jordan Hazen, jnh at vt11.net
# 
# Command-line utility to compile and flash your Arduino sketches
# directly at your UDOO device and upload to SAM3X flash
#
# You have to use a compatible Arduino compiler set and should use
# the bossac patched by UDOO. As an easy starter, we have prepared
# a headless Arduino compiler and source package. Read more at:
# https://github.com/TomFreudenberg/UDOO-headless-arduino-compile-and-flash
#
# Do not use this without an UDOO board. Standard DUE devices are not
# supported and may be get a defect otherwise.
#

ARDUINO_BASE_DIR="/usr/local/lib/udoo-arduino-cli"

# --- DO NOT CHANGE BELOW THIS LINE ----------------------------------

# Output name for project
SKETCH_NAME=""

# files to compile or flash for project
SOURCE_FILES=""
BINARY_FILES=""

# Output path
BUILD_PATH="/tmp/udoo-arduino-build-$$"

# board type
ARDUINO_BOARD="arduino_due_x"

# Standard UART to SAM3X
SAM3X_DEV="ttymxc3"

# Options defaults
OPT_USER_BUILD_PATH=false
OPT_FAST_BUILD=false
OPT_COPY_SKETCH_BIN=false
OPT_FLASH_BINARY=false
OPT_CLEAN_BUILD_PATH=false

# Compiler options
CMDLINE_ADDED_INC_PATH=""
CMDLINE_ADDED_ARDUINO_LIBS_FILES=""

# Simple help information
function __help () {
  echo "Usage for build:"
  echo "  $(basename $0) [-I <path>] [-L <library.cpp>] [-o <path> [--fast]] [--copy] [--clean] [--flash] sketch.ino [<sources.cpp>]"
  echo
  echo "Usage for flash:"
  echo "  $(basename $0) --flash sketch.bin"
  echo 
  echo "        -o = use <path> for build process output"
  echo "    --fast = fast build, skip build for Arduino standard sources if exists"
  echo "        -I = add <path> to INCLUDES search path"
  echo "        -L = add reference and includes to standard <library.cpp>, e.g. Wire.cpp"
  echo "    --copy = copy sketch .bin file to project directory after build process"
  echo "   --flash = erase and flash binary to SAM3X"
  echo "        -D = UART device to SAM3X, default: <ttymxc3>"
  echo "        -A = Arduino installation base path, default: </usr/local/lib/udoo-arduino-cli>"
  echo "   --clean = purge temp build directory after process on success and errors"
  echo "    --help = this help info"
  echo
  exit 1
}

# simple error message
#   parameter:
#     $1 = message
function __error() {
  echo "$(basename $0) - ${1}"
  echo
  exit 1
}

# check arguments
if [[ -z "${1}" ]]; then __help; fi

# get cmdline args
while [[ -n "${1}" ]]; do
  # get the options
  case "${1}" in
    -o)
      # check mandatory argument
      [[ "${2}" != "" && ${2::1} != "-" ]] || __error "Argument error: missing or wrong argument for build path [${2}]!"
      # set option flag
      OPT_USER_BUILD_PATH=true
      # set new build path
      BUILD_PATH="${2}"
      # skip additional argument
      shift 1
      ;;
    --fast)
      # check option dependency for own build path
      [[ "${OPT_USER_BUILD_PATH}" == true ]] || __error "Argument error: please specify own build path before using fast build!"
      # set option flag
      OPT_FAST_BUILD=true
      ;;
    -I)
      # check mandatory argument
      [[ "${2}" != "" && ${2::1} != "-" ]] || __error "Argument error: missing or wrong argument for additional include path [${2}]!"
      # set new include path
      CMDLINE_ADDED_INC_PATH="${CMDLINE_ADDED_INC_PATH} ${2}"
      # skip additional argument
      shift 1
      ;;
    -L)
      # check mandatory argument
      [[ "${2}" != "" && ${2::1} != "-" ]] || __error "Argument error: missing or wrong argument for additional library source [${2}]!"
      # set new library
      CMDLINE_ADDED_ARDUINO_LIBS_FILES="${CMDLINE_ADDED_ARDUINO_LIBS_FILES} ${2}"
      # skip additional argument
      shift 1
      ;;
    --copy)
      # set option flag
      OPT_COPY_SKETCH_BIN=true
      ;;
    --flash)
      # set option flag
      OPT_FLASH_BINARY=true
      ;;
    -D)
      # check mandatory argument
      [[ "${2}" != "" && ${2::1} != "-" ]] || __error "Argument error: missing or wrong argument for UART device identifier [${2}]!"
      # set new device
      SAM3X_DEV="${2}"
      # skip additional argument
      shift 1
      ;;
    -A)
      # check mandatory argument
      [[ "${2}" != "" && ${2::1} != "-" ]] || __error "Argument error: missing or wrong argument for Arduino installation path [${2}]!"
      # set new installation path
      ARDUINO_BASE_DIR="${2}"
      # skip additional argument
      shift 1
      ;;
    --clean)
      # set option flag
      OPT_CLEAN_BUILD_PATH=true
      ;;
    --help|-h)
      # show info
      __help
      ;;
    -*)
      # show error
      __error "Argument error: unknown option [${1}]!"
      ;;
    *)
      # append as source or binary file argument
      if [[ "${1:(-4)}" == ".bin" ]]; then
        BINARY_FILES="${BINARY_FILES} ${1}"
      else
        SOURCE_FILES="${SOURCE_FILES} ${1}"
      fi
      ;;
  esac
  # next arg
  shift 1
done

# Standard paths
ARDUINO_HW_TOOLS_DIR="${ARDUINO_BASE_DIR}/hardware/tools"
ARDUINO_HW_TOOLS_GCC_DIR="${ARDUINO_HW_TOOLS_DIR}/gcc-arm-none-eabi/bin"
ARDUINO_HW_SAM_DIR="${ARDUINO_BASE_DIR}/hardware/arduino/sam"
ARDUINO_HW_SAM_CORES_DIR="${ARDUINO_HW_SAM_DIR}/cores/arduino"
ARDUINO_HW_SAM_BOARD_DIR="${ARDUINO_HW_SAM_DIR}/variants/${ARDUINO_BOARD}"

# Compiler flags
CFLAGS_1="-c -g -Os -w -ffunction-sections -fdata-sections -nostdlib --param max-inline-insns-single=500"
CFLAGS_2="-fno-rtti -fno-exceptions"   # Used for C++ files only
CFLAGS_3="-Dprintf=iprintf -mcpu=cortex-m3 -DF_CPU=84000000L -DARDUINO=161 -DARDUINO_SAM_DUE -DARDUINO_ARCH_SAM -D__SAM3X8E__ -mthumb -DUSB_PID=0x003e -DUSB_VID=0x2341 -DUSBCON -DUSB_MANUFACTURER=\"Unknown\" -DUSB_PRODUCT=\"Udoo-SAM3X\""

# Compiler includes
ARDUINO_INC_PATH="-I${ARDUINO_HW_SAM_DIR}/system/libsam -I${ARDUINO_HW_SAM_DIR}/system/CMSIS/CMSIS/Include/ -I${ARDUINO_HW_SAM_DIR}/system/CMSIS/Device/ATMEL/ -I${ARDUINO_HW_SAM_CORES_DIR} -I${ARDUINO_HW_SAM_BOARD_DIR}"

# Standard Arduino C-Files to build the app
ARDUINO_C_FILES="WInterrupts.c syscalls_sam3.c cortex_handlers.c wiring.c wiring_digital.c itoa.c wiring_shift.c wiring_analog.c hooks.c iar_calls_sam3.c"
ARDUINO_CPP_FILES="main.cpp WString.cpp RingBuffer.cpp UARTClass.cpp USARTClass.cpp USB/CDC.cpp USB/HID.cpp USB/USBCore.cpp Reset.cpp Stream.cpp Print.cpp WMath.cpp IPAddress.cpp wiring_pulse.cpp"
ARDUINO_ARCH_FILES="variant.cpp"

# Standard Arduino libraries to include and build
ARDUINO_LIBS_INC_PATH=""
ARDUINO_LIBS_FILES=""

# Project include path
SKETCH_INC_PATH=""

# Test environment and options before start
[[ -n "${SOURCE_FILES}" && -n "${BINARY_FILES}" ]] && __error "Error arguments: cannot specify source and binary files at same time!"

[[ -n "${BINARY_FILES}" && "${OPT_FLASH_BINARY}" != true ]] && __error "Error arguments: must call -f flash option when specify binary files!"

[[ -z "${SOURCE_FILES}" && -z "${BINARY_FILES}" ]] && __error "Error missing arguments: no source or binary files specified!"

[[ "${OPT_COPY_SKETCH_BIN}" == true && -z "${SOURCE_FILES}" ]] && __error "Error copy binary: option is only allowed when using build process!"

[[ -d "${ARDUINO_BASE_DIR}" ]] || __error "Error installation: Arduino installation not available [${ARDUINO_BASE_DIR}]!"

[[ -c "/dev/${SAM3X_DEV}" ]] || __error "Error device: UART device to SAM3X does not exist [${SAM3X_DEV}]!"

[[ "${OPT_CLEAN_BUILD_PATH}" == true && "${OPT_USER_BUILD_PATH}" == true ]] && __error "Clean build path error: option is only allowed when using temporary build path!"

[[ "${OPT_CLEAN_BUILD_PATH}" == true && -z "${SOURCE_FILES}" ]] && __error "Clean build path error: option is only allowed when using build process!"

# Test for source files and project main file
for src_file in ${SOURCE_FILES}; do
  # check file
  [[ -f $src_file ]] || __error "File not found: could not locate source file [${src_file}]!"
  # test for sketch main file
  if [[ "${src_file:(-4)}" == ".ino" ]]; then
    # SKETCH ino file
    SKETCH_INO_FILE="${src_file}"
    # SKETCH Name
    SKETCH_NAME="$(basename ${src_file::(-4)})"
    # temporary SKETCH MAIN file
    SKETCH_TMP_MAIN_FILE="${BUILD_PATH}/tmp.${SKETCH_NAME}.ino.cpp"
  fi
done

# Test for binary files
for bin_file in ${BINARY_FILES}; do
  # check file
  [[ -f $bin_file ]] || __error "File not found: could not locate binary file [${bin_file}]!"
done

# build unique list of include paths for project
for unique_inc_path in $(
(
  for inc_path in ${CMDLINE_ADDED_INC_PATH}; do
    echo "${inc_path}"
  done
) | sort --unique); do
  SKETCH_INC_PATH="${SKETCH_INC_PATH} -I${unique_inc_path}"
done

# Try to find standard libraries to include and build if used by sketch. Normal libraries are
# organized at path <arduino>/libraries/<name>/src/<name>.(h|cpp) or at hardware path like
# <arduino>/hardware/arduino/libraries/<name>/<name>.(h|cpp). So check for "src" sub-path.
for std_lib_file in ${CMDLINE_ADDED_ARDUINO_LIBS_FILES}; do
  std_lib_files=$(find ${ARDUINO_BASE_DIR} -type f -path '*/libraries/*' -name "${std_lib_file}")
  if [[ -n "${std_lib_files}" ]]; then
    ARDUINO_LIBS_FILES="${ARDUINO_LIBS_FILES} ${std_lib_files}"
  else
    __error "Standard library error: could not locate library path for [${std_lib_file}]!"
  fi
done

# build unique list of include paths for libs
for unique_std_lib_path in $(
(
  for std_lib_file in ${ARDUINO_LIBS_FILES}; do
    echo $(dirname "${std_lib_file}")
  done
) | sort --unique); do
  ARDUINO_LIBS_INC_PATH="${ARDUINO_LIBS_INC_PATH} -I${unique_std_lib_path}"
done

# append to list if objects
function __obj_to_arduino_a () {
  if ! ${ARDUINO_HW_TOOLS_GCC_DIR}/arm-none-eabi-ar rcs ${BUILD_PATH}/arduino.a ${BUILD_PATH}/$1; then exit 1; fi
}

function __obj_to_sketch_a () {
  if ! ${ARDUINO_HW_TOOLS_GCC_DIR}/arm-none-eabi-ar rcs ${BUILD_PATH}/${SKETCH_NAME}.a ${BUILD_PATH}/$1; then exit 1; fi
}

function __build () {
  # test sketch main file
  [[ -n "${SKETCH_NAME}" ]] || __error "Project file missing: no .ino file was given!"
  # start build process
  echo "Building binary file for sketch [${SKETCH_NAME}] ..."
  echo
  # drop previous sketch.a for next run
  rm -f "${BUILD_PATH}/${SKETCH_NAME}.a"
  # drop previous arduino.a if not fast build
  [[ "${OPT_FAST_BUILD}" == true ]] || rm -f "${BUILD_PATH}/arduino.a"
  # run thru build process
  echo "CC (Project INO/CPP files)"
  for src_file in $*; do
    # test for sketch main file
    if [[ "${src_file:(-4)}" == ".ino" ]]; then
      # build sketch main cpp
      (
        # optionally add some headers by default
        # if nessecary for sketch.ino
        #
        # echo '// temporary sketch main file tmp.sketch.ino.cpp'
        # echo '// generated by udoo-arduino-build'
        # echo ''
        # echo '#include "Arduino.h"'
        # echo '#include "stdbool.h"'
        # echo ''
        #
        # append original sketch.ino source
        cat "${src_file}"
      ) > ${SKETCH_TMP_MAIN_FILE}
      # rewrite reference for tmp file
      src_file=${SKETCH_TMP_MAIN_FILE}
    fi
    # extract filename for output file
    obj_file=$(basename "${src_file}.o")
    # run g++
    ${ARDUINO_HW_TOOLS_GCC_DIR}/arm-none-eabi-g++ ${CFLAGS_1} ${CFLAGS_2} ${CFLAGS_3} ${ARDUINO_INC_PATH} ${ARDUINO_LIBS_INC_PATH} ${SKETCH_INC_PATH} ${src_file} -o ${BUILD_PATH}/${obj_file} || exit 1
    # on success add object file
    __obj_to_sketch_a $obj_file
  done

  if [[ -z "${SKETCH_NAME}" ]]; then
    echo "No INO main file was given!"
    exit 1
  fi

  echo "CC (Project added Arduino global library CPP files)"
  for src_file in ${ARDUINO_LIBS_FILES}; do
    # extract filename for output file
    obj_file=$(basename "${src_file}.o")
    # run g++
    if [[ "${OPT_FAST_BUILD}" != true || ! -f "${BUILD_PATH}/${obj_file}" ]]; then 
      ${ARDUINO_HW_TOOLS_GCC_DIR}/arm-none-eabi-g++ ${CFLAGS_1} ${CFLAGS_2} ${CFLAGS_3} ${ARDUINO_INC_PATH} ${ARDUINO_LIBS_INC_PATH} ${src_file} -o ${BUILD_PATH}/${obj_file} || exit 1
      # on success add object file
      __obj_to_arduino_a $obj_file
    fi
  done

  echo "CC (Arduino standard library C files)"
  for src_file in ${ARDUINO_C_FILES}; do
    # extract filename for output file
    obj_file=$(basename "${src_file}.o")
    # run gcc
    if [[ "${OPT_FAST_BUILD}" != true || ! -f "${BUILD_PATH}/${obj_file}" ]]; then 
      ${ARDUINO_HW_TOOLS_GCC_DIR}/arm-none-eabi-gcc ${CFLAGS_1} ${CFLAGS_3} ${ARDUINO_INC_PATH} ${ARDUINO_HW_SAM_CORES_DIR}/${src_file} -o ${BUILD_PATH}/${obj_file} || exit 1
      # on success add object file
      __obj_to_arduino_a $obj_file
    fi
  done

  echo "CC (Arduino standard library CPP files)"
  for src_file in ${ARDUINO_CPP_FILES}; do
    # extract filename for output file
    obj_file=$(basename "${src_file}.o")
    # run g++
    if [[ "${OPT_FAST_BUILD}" != true || ! -f "${BUILD_PATH}/${obj_file}" ]]; then 
      ${ARDUINO_HW_TOOLS_GCC_DIR}/arm-none-eabi-g++ ${CFLAGS_1} ${CFLAGS_2} ${CFLAGS_3} ${ARDUINO_INC_PATH} ${ARDUINO_HW_SAM_CORES_DIR}/${src_file} -o ${BUILD_PATH}/${obj_file} || exit 1
      # on success add object file
      __obj_to_arduino_a $obj_file
    fi
  done

  echo "CC (Arduino architecture files)"
  for src_file in ${ARDUINO_ARCH_FILES}; do
    # extract filename for output file
    obj_file=$(basename "${src_file}.o")
    # run g++
    if [[ "${OPT_FAST_BUILD}" != true || ! -f "${BUILD_PATH}/${obj_file}" ]]; then 
      ${ARDUINO_HW_TOOLS_GCC_DIR}/arm-none-eabi-g++ ${CFLAGS_1} ${CFLAGS_2} ${CFLAGS_3} ${ARDUINO_INC_PATH} ${ARDUINO_HW_SAM_BOARD_DIR}/${src_file} -o ${BUILD_PATH}/${obj_file} || exit 1
      # on success add object file
      __obj_to_arduino_a $obj_file
    fi
  done

  echo "LD (Link OBJ files)"
  ${ARDUINO_HW_TOOLS_GCC_DIR}/arm-none-eabi-g++ -Os -Wl,--gc-sections -mcpu=cortex-m3 -T${ARDUINO_HW_SAM_BOARD_DIR}/linker_scripts/gcc/flash.ld -Wl,-Map,${BUILD_PATH}/${SKETCH_NAME}.map -o ${BUILD_PATH}/${SKETCH_NAME}.elf -L${BUILD_PATH} -lm -lgcc -mthumb -Wl,--cref -Wl,--check-sections -Wl,--gc-sections -Wl,--entry=Reset_Handler -Wl,--unresolved-symbols=report-all -Wl,--warn-common -Wl,--warn-section-align -Wl,--warn-unresolved-symbols -Wl,--start-group ${BUILD_PATH}/syscalls_sam3.c.o ${SKETCH_TMP_MAIN_FILE}.o ${ARDUINO_HW_SAM_BOARD_DIR}/libsam_sam3x8e_gcc_rel.a ${BUILD_PATH}/${SKETCH_NAME}.a ${BUILD_PATH}/arduino.a -Wl,--end-group || exit 1

  echo "BIN (Build binary file for ${SKETCH_NAME}.bin)"
  ${ARDUINO_HW_TOOLS_GCC_DIR}/arm-none-eabi-objcopy -O binary ${BUILD_PATH}/${SKETCH_NAME}.elf ${BUILD_PATH}/${SKETCH_NAME}.bin || exit 1

  echo
  echo "Binary file is ready ..."
  du -sb ${BUILD_PATH}/${SKETCH_NAME}.bin
  BINARY_FILES="${BUILD_PATH}/${SKETCH_NAME}.bin"
  echo
}

function __copy_binary () {
  # test count of binaries to flash
  [[ "$#" -eq 1 ]] || __error "Copy binary error: can not copy more or less than 1 binary file!"
  # get target path from sketch ino file
  TARGET_PATH=$(dirname "${SKETCH_INO_FILE}")
  # run thru copy process
  echo "Copy binary file ["$(basename "${1}")"] to sketch folder ..."
  cp "${1}" "${TARGET_PATH}"
  echo
}

function __flash () {
  # test count of binaries to flash
  [[ "$#" -eq 1 ]] || __error "Flash error: can not flash more or less than 1 binary file!"
  # run thru flash process
  echo "Erasing SAM3X and flashing ${1} ..."
  ${ARDUINO_HW_TOOLS_DIR}/bossac --port=${SAM3X_DEV} -U false -e -w -v -b "${1}" -R
  echo
}

function __cleanup() {
  # save exit code
  EXIT_CODE=$?
  # Exit Handler deaktivieren
  trap - 0
  # check to remove build path
  [[ "${OPT_CLEAN_BUILD_PATH}" == true ]] && rm -rf "${BUILD_PATH}"
  # Skript beenden
  exit $EXIT_CODE
}

# add exit code handler
for sig in 0 1 2 3 6 14 15; do
  trap "__cleanup $sig" $sig
done

# create and check build path
mkdir -p "${BUILD_PATH}" && [[ -d "${BUILD_PATH}" ]] || __error "Error build destination: path not available or accesible [${BUILD_PATH}]!"

# check action to build
[[ "${SOURCE_FILES}" != "" ]] && __build ${SOURCE_FILES}

# check action for copy binary
[[ "${OPT_COPY_SKETCH_BIN}" == true ]] && __copy_binary ${BINARY_FILES}

# check action to flash
[[ "${OPT_FLASH_BINARY}" == true ]] && __flash ${BINARY_FILES}

# finished
exit 0
