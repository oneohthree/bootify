#!/bin/bash

VER="0.2.1"
echo $$

function usage()
{
cat <<EOF
Usage: $0 -d [DEVICE] -s [boot|uefi] -i [ISO]

Options:

-d [DEVICE]     USB device name, eg /dev/sdb
-s [boot|uefi]  boot method, 'boot' or 'uefi'
-i [ISO FILE]   path to the ISO file
-h              display this help and exit
-l              display available USB devices and exit
-v              display version and exit
EOF
}

function version()
{
	echo "bootify $VER"
}

function available_devices
{
	lsblk -ndo tran,name,vendor,model,size | grep usb | tr -s " "  " "
}

function mbr_part()
{
	BTS="res/bootstrap"
	parted -s -a optimal $DEV mktable msdos mkpart primary ntfs 1 100% set 1 boot
	mkfs.ntfs -f -L BOOTIFY ${DEV}1
	dd if=$BTS of=$DEV > /dev/null 2>&1 || { echo "Error injecting bootstrap" 1>&2; exit 1; }
	copy_files
}

function gpt_part()
{   
	parted -s -a optimal $DEV mktable gpt mkpart primary fat32 1 100%
	mkfs.vfat -F32 -n BOOTIFY ${DEV}1
	copy_files
}

function confirm()
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

function copy_files()
{
	mount ${DEV}1 /mnt
	mount -o ro $ISO /media
	cp -rv /media/* /mnt

	# Windows 7 missing UEFI boot file workaround
	# This does not happen with Windows 8 installation media

	if [[ "$SCH" == "uefi" ]]
	then
		if [[ ! -d /mnt/efi/boot ]]
		then
			WIM="/media/sources/install.wim"
			EFI="1/Windows/Boot/EFI/bootmgfw.efi"
			DST="/mnt/efi/boot"		
			7z e $WIM $EFI -o${DST} > /dev/null 2>&1 || { echo 1>&2 "Error extracting bootmgfw.efi"; exit 1; }
			mv ${DST}/bootmgfw.efi ${DST}/bootx64.efi
		fi
	fi

	sync
	sleep 5
	umount /mnt /media
	echo "Your USB drive has been bootified"
	exit 0
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

# bootify needs all the parameters

if [[ -z "$DEV" ]] || [[ -z "$SCH" ]] || [[ -z "$ISO" ]]
then
	usage
	exit 1
fi

# Check if dependencies are met

DEP="dd isoinfo lsblk mkfs.ntfs mkfs.vfat parted sha1sum stat 7z"
for D in $DEP
do
    type $D > /dev/null 2>&1 || { echo "$D is not ready" 1>&2; exit 1; }
done

# Check if bootstrap exists

SHA=$(sha1sum res/bootstrap | cut -f1 -d " ")

if [[ ! -f res/bootstrap ]]
then
	echo "bootstrap does not exist" 1>&2
	exit 1
fi

# Check bootstrap integrity

if [[ "$SHA" != "9db0cc63f8b6fda3b50ab82e27625c69026a4735" ]]
then
	echo "bootstrap file is corrupt" 1>&2
	exit 1
fi

# Make sure bootify runs as root

if [[ "$EUID" -ne 0 ]]
then
	echo "bootify must be run as root" 1>&2
	exit 1
fi

# Check if $DEV is a block device

if [[ ! -b "$DEV" ]]
then
	echo "$DEV is not a block device" 1>&2
	exit 1
fi

# Check if $DEV is a USB device

if [[ -z $(lsblk -ndo tran $DEV | grep usb) ]]
then
	echo "$DEV is not a USB device" 1>&2
	exit 1
fi

# Check if $DEV is mounted

if [[ ! -z $(grep $DEV /proc/mounts) ]]
then
	echo "$DEV is mounted, dismount it and run bootify again" 1>&2
	exit 1
fi

# Check if $ISO exists and is valid

if [[ ! -f "$ISO" ]]
then
	echo "$ISO does not exist" 1>&2
	exit 1
elif [[ -z $(isoinfo -d -i "$ISO" | grep "CD-ROM is in ISO 9660 format") ]]
then
	echo "$ISO is not a valid ISO file" 1>&2
	exit 1
fi

# Check $DEV capacity

if [[ $(stat -c %s $ISO) -gt $(lsblk -ndbo size $DEV) ]]
then
	echo "The device capacity is insufficient" 1>&2
	exit 1
fi

# Check if /media directory exists

if [[ ! -d /media ]]
then
	mkdir /media
fi

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
	echo "Incorrect boot method, use 'boot' or 'uefi'" 1>&2
	usage
	exit 1
fi
