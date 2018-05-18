#!/bin/bash

fs=${FILESYSTEM}
if [ "$fs" != "nfs" -a "$fs" != "gluster" -a "$fs" != "lustre" ]; then
  echo You must set FILESYSTEM environment variable to one of the followings: nfs, gluster or lustre
  exit 1
fi

ip=${SERVER_IP}
if [ -z "$ip" ]; then
  echo You must set SERVER_IP environment variable to specify the IP address of the file server
  exit 1
fi
if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  ping -q -c2 $ip > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo Failed to ping $ip
    exit 1
  fi
else
  echo Invalid IP address: $ip
  exit 1
fi

type=${TEST_TYPE}
if [ "$type" != "copy" -a "$type" != "compile" -a "$type" != "all" ]; then
  echo You must set TEST_TYPE environment variable to one of the followings: copy, compile or all
  exit 1
fi

export TZ="America/Toronto"

home=/home/centos
sudo rm -rf $home/$fs
mkdir -p $home/$fs
date=`date +%s`
host=`hostname --short`
log="$home/$fs/$host.$date.log"
test_dir=test

echo ======================================= >> $log 2>&1

mount=/mnt/$fs
sudo mkdir -p $mount
echo Mount $mount >> $log 2>&1
sudo umount -f $mount >> $log 2>&1
if [ "$fs" = "nfs" ]; then
  echo sudo mount -o vers=3 $ip:/var/nfsshare $mount
  sudo mount -o vers=3 $ip:/var/nfsshare $mount >> $log 2>&1
  if [ $? -ne 0 ]; then
    echo Failed to mount $mount >> $log 2>&1
    echo ======================================= >> $log 2>&1
    exit 1
  fi
elif [ "$fs" = "gluster" ]; then
  sudo mount $ip:/gv-dist-0 $mount 
  sudo mount $ip:/gv-dist-0 $mount >> $log 2>&1
  if [ $? -ne 0 ]; then
    echo Failed to mount $mount >> $log 2>&1
    echo ======================================= >> $log 2>&1
    exit 1
  fi
elif [ "$fs" = "lustre" ]; then
  echo sudo modprobe lnet >> $log 2>&1
  sudo modprobe lnet >> $log 2>&1
  echo sudo lnetctl lnet configure >> $log 2>&1
  sudo lnetctl lnet configure >> $log 2>&1
  echo sudo lnetctl net add --net tcp1 --if ens5 >> $log 2>&1
  sudo lnetctl net add --net tcp1 --if ens5 >> $log 2>&1
  echo sudo modprobe lustre >> $log 2>&1
  sudo modprobe lustre >> $log 2>&1
  echo sudo mount -t lustre -o localflock $ip@tcp1:/lustre $mount >> $log 2>&1
  sudo mount -t lustre $ip@tcp1:/lustre $mount >> $log 2>&1
  if [ $? -ne 0 ]; then
    echo Failed to mount $mount >> $log 2>&1
    echo ======================================= >> $log 2>&1
    exit 1
  fi
  if [ ! -d "$mount/$test_dir" ]; then
    echo Directory $mount/$test_dir does not exist. >> $log 2>&1
    echo ======================================= >> $log 2>&1
    exit 1
  fi
  # Performance tuning parameters
  echo sudo lctl set_param osc./*.checksums=0 >> $log 2>&1
  sudo lctl set_param osc./*.checksums=0 >> $log 2>&1
  echo sudo lctl set_param osc./*.max_dirty_mb=128 >> $log 2>&1
  sudo lctl set_param osc./*.max_dirty_mb=128 >> $log 2>&1
  echo sudo lctl set_param osc./*.max_rpcs_in_flight=32 >> $log 2>&1
  sudo lctl set_param osc./*.max_rpcs_in_flight=32 >> $log 2>&1
fi

source=$home/gcc-4.9.2
ami_launch_index=`curl http://169.254.169.254/latest/meta-data/ami-launch-index`
group=${TEST_GROUP}
if [ -n "$group" ]; then
  file=gcc.`hostname`.$group.$ami_launch_index
else
  file=gcc.`hostname`.$ami_launch_index
fi
dest=$mount/$test_dir/$file

if [ "$type" = "copy" -o "$type" = "all" ]; then
  date >> $log 2>&1
  echo Copy to $dest >> $log 2>&1
  (time cp -rf $source $dest) >> $log 2>&1
  date >> $log 2>&1
fi

if [ "$type" != "copy" ]; then
  # Need to compile
  cd $dest
  echo Configure ... >> $log 2>&1
  (time ./configure --disable-multilib --enable-languages=c,c++) >> $log 2>&1
  echo Compile ... >> $log 2>&1
  ($mount/elmake -y) >> $log 2>&1
  if [ $? -ne 0 ]; then
    echo Retry compiling after 10 seconds ... >> $log 2>&1
    sleep 10
    ($mount/elmake -y) >> $log 2>&1
    if [ $? -ne 0 ]; then
      echo Compile failed ... >> $log 2>&1
    fi
  fi
fi

echo ======================================= >> $log 2>&1
cp $log $mount/output/test.$type.$host.$date.log

