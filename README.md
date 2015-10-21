# bootify

bootify is a Bash script to make bootable USB drives with Windows 7/8 
installation files. It can be used for Boot or UEFI systems.

## Dependencies

Make sure the following tools exist on your system:

* `dd`
* `lsblk`
* `isoinfo`
* `mkfs.ntfs`
* `mkfs.vfat`
* `parted`
* `sha1sum`
* `stat`
* `7z`

## Usage

Make sure `bootify.sh` is executable: `chmod +x bootify.sh`

`sudo ./bootify.sh -d [DEVICE] -s [boot|uefi] -i [ISO]`

## Todo

* Provide a nice progress indicator
* Handle interruption events
