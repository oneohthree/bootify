#!/bin/bash
## bootify: make bootable USB drives with Windows 7/8/8.1/10 installation files
#
# Copyright (C) 2015-2017 oneohthree
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

VER="0.2.3"

usage()
{
  cat <<-EOF
  Usage: bootify -d [DEVICE] -s [boot|uefi] -i [ISO]

  -d [DEVICE]       USB device name, eg /dev/sdb
  -s [boot|uefi]    boot method, 'boot' or 'uefi'
  -i [ISO FILE]     path to the ISO file
  -h                display this help and exit
  -l                display available USB devices and exit
  -v                display version and exit
EOF
}

version()
{
  echo "bootify $VER"
}

available_devices()
{
  lsblk -ndo tran,name,vendor,model,size | grep usb | tr -s " "  " "
}

checks()
{
  # Check parameters
  if [[ -z "$DEV" ]] || [[ -z "$SCH" ]] || [[ -z "$ISO" ]]
  then
    usage
    exit 1
  fi

  # Check if dependencies are met
  DEP="dd file stat lsblk parted mkfs.ntfs mkfs.vfat 7z rsync"
  for D in $DEP
  do
    type $D > /dev/null 2>&1 || { echo "ERROR: $D is missing" 1>&2; exit 1; }
  done

  # Check if bootstrap exists
  if [[ ! -f mbr.bin && "$SCH" == "boot" ]]
  then
    echo "ERROR: bootstrap file does not exist" 1>&2
    exit 1
  fi

  # Check if bootify runs as root
  if [[ "$EUID" -ne 0 ]]
  then
    echo "ERROR: bootify must be run as root" 1>&2
    exit 1
  fi

  # Check if $DEV is a block device
  if [[ ! -b "$DEV" ]]
  then
    echo "ERROR: $DEV is not a block device" 1>&2
    exit 1
  fi

  # Check if $DEV is a USB device
  if [[ -z $(lsblk -ndo tran $DEV | grep usb) ]]
  then
    echo "ERROR: $DEV is not a USB device" 1>&2
    exit 1
  fi

  # Check if $DEV is mounted
  if [[ ! -z $(grep $DEV /proc/mounts) ]]
  then
    echo "ERROR: $DEV is mounted, unmount it and run bootify again" 1>&2
    exit 1
  fi

  # Check if $ISO exists and is bootable

  if [[ ! -f "$ISO" ]]
  then
    echo "ERROR: $ISO does not exist" 1>&2
    exit 1
  elif [[ -z $(file "$ISO" | grep "bootable") ]]
  then
    echo "ERROR: $ISO is not bootable" 1>&2
    exit 1
  fi

  # Check $DEV capacity

  if [[ $(stat -c %s "$ISO") -gt $(lsblk -ndbo size $DEV) ]]
  then
    echo "ERROR: The device capacity is insufficient" 1>&2
    exit 1
  fi
}

confirm()
{
  DSC=$(lsblk -ndo vendor,model,size $DEV | tr -s " " " ")
  read -p "$DSC is going to be formated. Do you want to continue? (Y/N)" YN
  if [[ "$YN" == [Yy] ]]
  then
    true
  elif [[ "$YN" == [Nn] ]]
  then
    exit 0
  else
    echo "Please, use 'Y' or 'N'"
    confirm
  fi
}

partitioning()
{
  if [[ "$SCH" == "boot" ]]
  then
    parted -s -a optimal $DEV mktable msdos mkpart primary ntfs 1 100% set 1 boot
    mkfs.ntfs -f -L BOOTIFY ${DEV}1
    # dd if=/usr/lib/syslinux/bios/mbr.bin of=$DEV bs=446 count=1 conv=notrunc
    dd if=mbr.bin of=$DEV bs=446 count=1 conv=notrunc > /dev/null 2>&1 || { echo "Error injecting bootstrap" 1>&2; exit 1; }
  elif [[ "$SCH" == "uefi" ]]
  then
    parted -s -a optimal $DEV mktable gpt mkpart primary fat32 1 100%
    mkfs.vfat -F32 -n BOOTIFY ${DEV}1
  else
    echo "ERROR: Incorrect boot method, use 'boot' or 'uefi'" 1>&2
    usage
    exit 1
  fi
}

copy_files()
{
  mkdir -p /tmp/{src,dst}
  mount -o loop "$ISO" /tmp/src
  mount ${DEV}1 /tmp/dst
  rsync -r --info=progress2 /tmp/src/ /tmp/dst/

  # Windows 7 missing UEFI boot file workaround

  if [[ "$SCH" == "uefi" ]]
  then
    if [[ ! -d /tmp/src/efi/boot ]]
    then
      WIM="/tmp/src/sources/install.wim"
      EFI="1/Windows/Boot/EFI/bootmgfw.efi"
      DST="/tmp/dst/efi/boot"   
      7z e $WIM $EFI -o${DST} > /dev/null 2>&1 || { echo 1>&2 "Error extracting bootmgfw.efi"; exit 1; }
      mv ${DST}/bootmgfw.efi ${DST}/bootx64.efi
    fi
  fi

  sync
}

finish()
{
  umount /tmp/{src,dst}
  echo "Your USB drive has been bootified!"
}

while getopts ":hlvd:s:i:" OPT
do
  case $OPT in
    h)
      usage
      exit 0
      ;;
    v)
      version
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
finish
