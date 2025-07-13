#!/bin/bash -xe

ARCH=arm64
CROSS_COMPILE=aarch64-linux-gnu-
DEFCONFIG=nanopi_r5c_defconfig
TOOLCHAIN=/opt/gcc-linaro-14.0.0-2023.06-x86_64_aarch64-linux-gnu
OUTPUT=${OUTPUT:-output}

BUILDENV="ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}"
KERNEL_VER=$(make -s kernelrelease)

export PATH=${TOOLCHAIN}/bin:$PATH

function prepare {
    mkdir ${OUTPUT}
}

function build_kernel {
    make ${BUILDENV} ${DEFCONFIG}
    cp .config ${OUTPUT}/${KERNEL_VER}-configs
    make ${BUILDENV} -j$(nproc) Image modules
    cp arch/arm64/boot/Image ${OUTPUT}
}

function build_dtbs {
    make ${BUILDENV} -j$(nproc) dtbs
}

function install_modules {
    local root=$1

    sudo make ${BUILDENV} INSTALL_MOD_PATH=${root} modules_install
}

function make_uinitrd {
    local srcimg="${PWD}/r5c_resource/initrd.img"
    local tmpdir=$(mktemp -d)

    pushd ${tmpdir}
    mkdir initrd && cd initrd
    zcat ${srcimg} | sudo cpio -i
    popd

    install_modules "${tmpdir}/initrd"

    local output="${PWD}/${OUTPUT}/initrd.img"
    pushd "${tmpdir}/initrd"
    find . | cpio -o -H newc | gzip > ${output}
    popd

    pushd ${OUTPUT}
    mkimage -A arm64 -O linux -T ramdisk -C gzip -n "initrd" -d initrd.img uInitrd
    popd

    sudo rm -rf ${tmpdir}
}

function pack_dtbs {
    local dtb="arch/arm64/boot/dts/rockchip/rk3568-nanopi-r5c.dtb"
    local dtb_dir="${OUTPUT}/dtb/rockchip"
    local dtbo_dir="${OUTPUT}/dtb/rockchip/overlay"

    mkdir -p ${dtb_dir} ${dtbo_dir}

    cp -a ${dtb} ${dtb_dir}
    cp -a r5c_resource/*.dtbo ${dtbo_dir}
}

# prepare
build_kernel
build_dtbs
install_modules ${OUTPUT}
make_uinitrd
pack_dtbs
