#!/bin/bash
## bootify: make bootable USB drives with Windows 7/8/8.1/10 installation files
#
# Copyright (C) 2015-2018 oneohthree
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

VER="0.3"

usage() {
  cat <<-EOF
  Usage: bootify -d [DEVICE] -s [boot|uefi] -i [ISO]

  -d [DEVICE]       USB device name, eg /dev/sdb
  -s [boot|uefi]    boot method, 'boot' or 'uefi'
  -i [ISO FILE]     path to the ISO file
  -h                display this help and exit
  -l                display available USB devices and exit
EOF
}

error() {
  echo "$@" 1>&2
  exit 1
}

available_devices() {
  lsblk -ndo tran,name,vendor,model,size | grep usb | tr -s " "  " "
}

checks() {
  # Check parameters
  if [[ -z "$DEV" ]] || [[ -z "$SCH" ]] || [[ -z "$ISO" ]]; then
    usage
    exit 1
  fi

  # Check if bootify runs as root
  if [[ "$EUID" -ne 0 ]]; then
    error "ERROR: bootify must be run as root"
  fi

  # We need these tools
  tools="dd file stat mktemp lsblk parted mkfs.ntfs mkfs.vfat 7z rsync"
  for tool in $tools; do
    type "$tool" > /dev/null 2>&1 || error "ERROR: \"$tool\" is missing"
  done

  # Check if $DEV is a block device
  if [[ ! -b "$DEV" ]]; then
    error "ERROR: \"$DEV\" is not a block device"
  fi

  # Check if $DEV is a USB device
  if [[ -z $(lsblk -ndo tran $DEV | grep usb) ]]; then
    error "ERROR: \"$DEV\" is not a USB device"
  fi

  # Check if $DEV is mounted
  if [[ ! -z $(grep $DEV /proc/mounts) ]]; then
    error "ERROR: \"$DEV\" is mounted, unmount it and run bootify again"
  fi

  # Check $DEV capacity
  if [[ $(stat -c %s "$ISO") -gt $(lsblk -ndbo size $DEV) ]]; then
    error "ERROR: The device capacity is insufficient"
  fi

  # Check if $ISO file exists and is bootable
  if [[ ! -f "$ISO" ]]; then
    error "ERROR: \"$ISO\" does not exist"
  elif [[ -z $(file "$ISO" | grep "bootable") ]]; then
    error "ERROR: \"$ISO\" is not bootable"
  fi

  # Check if bootstrap file exists
  if [[ ! -f mbr.bin && "$SCH" == "boot" ]]; then
    error "ERROR: bootstrap file does not exist"
  fi
}

confirm() {
  device=$(lsblk -ndo vendor,model,size $DEV | tr -s " " " ")
  read -p "$device is going to be formated! Do you want to continue? (Y/N)" YN
  if [[ "$YN" == [Yy] ]]; then
    true
  elif [[ "$YN" == [Nn] ]]; then
    exit 0
  else
    echo "Please, use 'Y' or 'N'"
    confirm
  fi
}

partitioning() {
  if [[ "$SCH" == "boot" ]]; then
    parted -s -a optimal $DEV mktable msdos mkpart primary ntfs 1 100% set 1 boot
    mkfs.ntfs -f -L BOOTIFY ${DEV}1
    dd if=mbr.bin of=$DEV bs=446 count=1 conv=notrunc > /dev/null 2>&1 ||
      error "Error injecting bootstrap"
  elif [[ "$SCH" == "uefi" ]]; then
    parted -s -a optimal $DEV mktable gpt mkpart primary fat32 1 100%
    mkfs.vfat -F32 -n BOOTIFY ${DEV}1
  else
    error "ERROR: Incorrect boot method, use 'boot' or 'uefi'"
    usage
    exit 1
  fi
}

copy_files() {
  src_dev=$(mktemp -d /mnt/bootify.XXXXXXXXX)
  dst_dev=$(mktemp -d /mnt/bootify.XXXXXXXXX)
  mount -o ro,loop "$ISO" $src_dev
  mount ${DEV}1 $dst_dev
  rsync -r --info=progress2 $src_dev/ $dst_dev

  # Windows 7 missing UEFI boot file workaround
  if [[ "$SCH" == "uefi" ]]; then
    if [[ ! -d $src_dev/efi/boot ]]; then
      wim_file="$src_dev/sources/install.wim"
      efi_file="1/Windows/Boot/EFI/bootmgfw.efi"
      boot_dir="$dst_dev/efi/boot"
      7z e $wim_file $efi_file -o${boot_dir} > /dev/null 2>&1 ||
        error "Error extracting bootmgfw.efi"
      mv ${boot_dir}/bootmgfw.efi ${boot_dir}/bootx64.efi
    fi
  fi

  sync

  umount $src_dev $dst_dev

  echo "Your USB drive has been bootified!"
}

while getopts ":hlvd:s:i:" OPT
do
  case $OPT in
    h)
      usage
      exit 0
      ;;
    l)
      available_devices
      exit 0
      ;;
    d)
      DEV="$OPTARG"
      ;;
    s)
      SCH="$OPTARG"
      ;;
    i)
      ISO="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" 1>&2
      usage
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument" 1>&2
      usage
      exit 1
      ;;
  esac
done

checks
confirm
partitioning
copy_files

exit 0
