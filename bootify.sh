#!/bin/bash

usage() {
	echo "Usage: $0 -d [device] -s [boot|uefi] -i [ISO]"
}

while getopts ":hd:s:i:" OPT
do
	case $OPT in
		h)
			usage
			exit 0
			;;
		d)
			DEV="$OPTARG"
			;;
		s)
			SCH="$OPTARG"
			;;
		i)
			ISO=$OPTARG
			;;
		\?)
			echo "Invalid parameter: -$OPTARG" >&2
			usage
			exit 1
			;;
		:)
			echo "Parameter -$OPTARG requires an argument" >&2
			usage
			exit 1
			;;
	esac
done

# bootify needs all the parameters

if [[ -z "$DEV" ]] || [[ -z "$SCH" ]] || [[ -z "$ISO" ]]
then
	usage
	exit 1
fi

# Check if dependencies are met

type parted > /dev/null 2>&1 || { echo >&2 "parted is not ready"; exit 1; }
type mkfs.ntfs > /dev/null 2>&1 || { echo >&2 "mkfs.ntfs is not ready"; exit 1; }
type mkfs.vfat > /dev/null 2>&1 || { echo >&2 "mkfs.vfat is not ready"; exit 1; }
type lsblk > /dev/null 2>&1 || { echo >&2 "lsblk is not ready"; exit 1; }
type 7za > /dev/null 2>&1 || { echo >&2 "7za is not ready"; exit 1; }

# Check if bootsect exists

if [[ ! -f res/bootsect ]]
then
	echo "bootsect does not exist"
	exit 1
fi

# Check if DEVICE is a block device

if [[ ! -b "$DEV" ]]
then
	echo "$DEV is not a block device"
	exit 1
fi

# Check if DEVICE is mounted

if [[ ! -z $(grep $DEV /proc/mounts) ]]
then
	echo "$DEV is mounted, dismount it and run bootify again"
	exit 0
fi

# Check if ISO file exists
# TODO: check if ISO has a UDF filesystem

if [[ ! -f "$ISO" ]]
then
	echo "$ISO does not exist"
	exit 1
fi

# Check DEVICE capacity

if [[ $(du -b $ISO | cut -f1) -gt $(lsblk -ndbo size $DEV) ]]
then
	echo "The device capacity is insufficient"
	exit 0
fi

# Check if /media directory exists

if [[ ! -d /media ]]
then
	mkdir /media
fi

mbr_part()
{
	parted -s -a optimal $DEV mktable msdos mkpart primary ntfs 1 100% set 1 boot
	mkfs.ntfs -f -L BOOTIFY ${DEV}1
	dd if=res/bootsect of=$DEV > /dev/null 2>&1
	copy_files
}

gpt_part()
{	
	parted -s -a optimal $DEV mktable gpt mkpart primary fat32 1 100%
	mkfs.vfat -F32 -n BOOTIFY ${DEV}1
	copy_files
}

copy_files()
{
	mount ${DEV}1 /mnt
	mount -o loop $ISO /media
	# TODO: provide a nicer progress indicator
	cp -rv /media/* /mnt

	# Windows 7 missing UEFI boot file workaround
	# This does not happens with Windows 8 installation media

	if [[ "$SCH" == "uefi" ]]
	then
		if [[ ! -d /mnt/efi/boot ]]
		then
			mkdir /mnt/efi/boot
			cd /mnt/efi/boot
			7z e /media/sources/install.wim 1/Windows/Boot/EFI/bootmgfw.efi > /dev/null 2>&1
			mv bootmgfw.efi bootx64.efi
		fi
	fi

	sync
	umount /mnt /media
	echo "Process finished successfully"
	exit 0
}

confirm()
{
	DSC=$(lsblk -ndo vendor,model,size $DEV | tr -s " " " ")
	read -p "$DEV ($DSC) is going to be formated. Do you want to continue? (Y/N)" YN
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

# Go to partitioning stage based on chosen boot method

if [[ "$SCH" == "boot" ]]
then
	confirm
	mbr_part
elif [[ "$SCH" == "uefi" ]]
then
	confirm
	gpt_part
else
	echo "Incorrect boot method, use 'boot' or 'uefi'"
	usage
	exit 1
fi