# bootify

**bootify** is a Bash script to make USB drives bootables with Windows 7/8 
installation files. It can be used for boot or UEFI systems.

## Dependencies

Make sure you have installed the following packages on your system.

* parted
* ntfs-3g
* dosfstools
* lsblk
* p7zip

## Usage

Make sure `bootify.sh` is executable: `chmod +x bootify.sh`

`sudo ./bootify -d [device] -s [boot|uefi] -i [ISO]`

* `-d` Should be a block device name, eg: /dev/sdb
* `-s` `boot` for legacy systems or `uefi` for modern systems
* `-i` The path to the ISO file

## Acknowledgements

bootify is a Bash script by oneohthree [sudo](http://sudo.cubava.cu/).