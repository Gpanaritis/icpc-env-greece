#!/bin/bash

# Kill all the user processes(and wait for them to die)
killall -9 -u contestant
sleep 5

DISK=$(blkid -L "ICPC")
if [[ $? == 0 ]]; then
    echo "Wiping FAT32 Partition"
    umount $DISK
    mkfs.vfat $DISK -n ICPC
fi

# Deletes all files owned by the contestant user, then deletes and recreates the account.
echo "Deleting team files"
find / -user contestant -delete

echo "Deleting contestant user"
userdel contestant
rm -rf /home/contestant

echo "Recreating contestant user"
useradd -d /home/contestant -m contestant -s /bin/bash
passwd -d contestant