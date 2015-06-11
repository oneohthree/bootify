# bootify

bootify is a Bash script to make USB drives bootables with Windows 7/8 
installation files. It can be used for boot or UEFI systems.

## Dependencies

Make sure the following tools exist on your system:

* `dd`
* `lsblk`
* `isoinfo`
* `mkfs.ntfs`
* `mkfs.vfat`
* `parted`
* `stat`
* `7za`

## Usage

Make sure `bootify.sh` is executable: `chmod +x bootify.sh`

`sudo ./bootify -d [DEVICE] -s [boot|uefi] -i [ISO]`

## Todo

* Provide a nice progress indicator
* Handle interruption events

## Acknowledgements

bootify is a project by [oneohthree](https://sudo.cubava.cu)