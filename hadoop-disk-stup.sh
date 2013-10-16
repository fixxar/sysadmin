#!/bin/bash
#Fixxar

DISKS=`cat /proc/partitions |awk '{print $4}'|grep ^sd|grep -v "[0-9]"|grep -v sda|sort`

echo "Creating partitions on sda"
#parted -s /dev/sda mkpart p ext3 410626048s 703653887s 
#parted -s /dev/sda mkpart p ext3 703653889s 1875771392s
echo "/dev/sda3		/mapr1			ext4	defaults,noatime,nodiratime	1 2" >> /tmp/add_to_fstab 
echo "/dev/sda4		/data1			ext4	defaults,noatime,nodiratime	1 2" >> /tmp/add_to_fstab 

x=2

for i in $DISKS
do
	echo "Erasing $i"
	parted -s /dev/$i mklabel msdos
	echo "Creating partition for mapr"
	parted -s /dev/$i mkpart p ext3 0% 20%
	echo "Creating partition for HDFS"
	parted -s /dev/$i mkpart p ext3 20% 100%
	echo "Adding /mapr${x} and /data${x} to fstab"
	echo "/dev/${i}1		/mapr${x}			ext4	defaults,noatime,nodiratime	1 2" >> /tmp/add_to_fstab
	echo "/dev/${i}2		/data${x}			ext4	defaults,noatime,nodiratime	1 2" >> /tmp/add_to_fstab 
	x=$((x+1))
done

/sbin/partprobe

for i in $DISKS
do
	echo "Creating ext4 filesystem on /dev/$i"
	mkfs.ext4 /dev/${i}1 2>1 > /tmp/mkfs.${i}1 &
done
wait
for i in $DISKS
do 
	echo "Creating ext4 filesystem on /dev/$i"
	mkfs.ext4 /dev/${i}2 2>1 > /tmp/mkfs.${i}2 &
done
mkfs.ext4 /dev/sda3 2>1 > /tmp/mkfs.sda3 &
mkfs.ext4 /dev/sda4 2>1 > /tmp/mkfs.sda4 &
echo "waiting for mkfs to complete"
wait
echo "mkfs complete"
echo "Adding disks to fstab"
cat /tmp/add_to_fstab >> /etc/fstab
echo "Mounting partitions"

for i in `seq 1 10`
do
        echo "Mounting /mapr$i"
        mkdir /mapr$i
        mount /mapr$i && mkdir /mapr$i/hadoop && chown hadoop:hadoop /mapr$i/hadoop
done
for i in `seq 1 10`
do 
	echo "Mounting /data$i"
	mkdir /data$i
	mount /data$i && mkdir /data$i/hadoop && chown hadoop:hadoop /data$i/hadoop
done

#rm /usr/local/sbin/pssc-disk-setup.sh
sed -i 's/^bash /#bash /' /etc/rc.d/rc.local
