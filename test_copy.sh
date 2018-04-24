#!/bin/bash

USAGE="Usage: $0  <nfs \| glustera> <server_ip>"

if [ "$#" -le 2 ]; then
  echo $USAGE
  exit 1
fi

fs=$1
if [ "$fs" != "nfs" -a "$fs" != "gluster" ]; then
  echo $USAGE
  exit 1
fi

ip=$2
if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  ping -q -c2 $ip
  if [ $? -ne 0 ]; then
    echo Failed to ping $ip
    exit 1
  fi
else
  echo Invalid IP address: $ip
  exit 1
fi

export TZ="America/Toronto"

home=/home/centos
mkdir -p $home/$fs
date=`date +%s`
host=`hostname --short`
log="$home/$fs/$host.$date.log"

echo ======================================= >> $log 2>&1

mount=/mnt/$fs
sudo mkdir -p $mount
echo Mount $mount >> $log 2>&1
if [ "$fs" = "nfs" ]; then
  sudo umount -f $mount >> $log 2>&1
  sudo mount -o vers=3 $ip:/var/nfsshare $mount >> $log 2>&1
  if [ $? -ne 0 ]; then
    echo Failed to mount $mount >> $log 2>&1
    echo ======================================= >> $log 2>&1
    exit 1
  fi
elif [ "$fs" = "gluster" ]; then
  sudo umount -f $mount >> $log 2>&1
  sudo mount $ip:/gv-dist-0 $mount >> $log 2>&1
  if [ $? -ne 0 ]; then
    echo Failed to mount $mount >> $log 2>&1
    echo ======================================= >> $log 2>&1
    exit 1
  fi
fi

source=$home/gcc-4.9.2
ami_launch_index=`curl http://169.254.169.254/latest/meta-data/ami-launch-index`
if [ "$#" -eq 3 ]; then
  group="$3"
  file=gcc.$group.$ami_launch_index
else
  file=gcc.$ami_launch_index
fi
dest=$mount/$file

date >> $log 2>&1
echo Copy to $dest >> $log 2>&1
(time cp -rf $source $dest) >> $log 2>&1
echo ======================================= >> $log 2>&1

cp $log $mount/output

