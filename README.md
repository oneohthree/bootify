# bootify

bootify is a Bash script to make bootable USB drives with Windows 7/8/10 
installation files. It can be used for Boot or UEFI systems.

## Dependencies

Make sure the following tools exist on your system:

* `stat`
* `file`
* `lsblk`
* `dd`
* `mkfs.ntfs`
* `mkfs.vfat`
* `parted`
* `7z`

## Usage

Make sure `bootify.sh` is executable: `chmod +x bootify.sh`

`sudo ./bootify.sh -d [DEVICE] -s [boot|uefi] -i [ISO]`

## Todo

* Provide a nice progress indicator
* Handle interruption events

## Bugs

* Old `lsblk` version have less available columns to report device data.
* You can't prepare a Windows 7 32bits in UEFI mode. UEFI is supported from Windows 7 64bits onwards.
