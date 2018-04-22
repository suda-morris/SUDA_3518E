# SUDA_3518E用户手册

### Hi3518EV200芯片特点

* ARM926@550MHz
* 1280x960@30fps or 1920x1080@15fps  H.264 HP encoding
* Max.2M Pixel sensor input
* Digital WDR, Tone mapping
* 64MBintegrated DDR



### 安装交叉编译器

> 安装海思官方提供的编译器**arm-hisiv300-linux**，使用的C库为uclibc，gcc版本为4.8.3，支持的内核版本为3.5.4

```bash
#!/bin/bash

TOP_DIR=/opt/hisi-linux/x86-arm
TOOL_DIR=$TOP_DIR/arm-hisiv300-linux
TAR_BIN_DIR=$TOOL_DIR/target/bin
BIN_FILES=$TOOL_DIR/bin/arm-hisiv300-linux-uclibcgnueabi-*
LN_FILE_NAME=arm-hisiv300-linux-
TOOLS_PKG="`dirname $0`/arm-hisiv300-linux.tar.bz2"

set +e

if [ -z "$1" ] 
then
	echo "CROSS_COMPILER_PATH=$TAR_BIN_DIR"
	if [ -f $TOOL_DIR/version ]
	then
		if [ -n "`grep 110310 $TOOL_DIR/version`" ]
		then
			echo "Cross Tools has been installed yet!" >&2
			exit 0
		fi
	else
		echo "Do not have version file" >&2
	fi

	eval $0 force
	[ $? == 0 ] && exit 0

	echo "sorry, you must have super privilege!" >&2
	select choose in 'I have root passwd' 'I have sudo privilege' 'Try again' 'Ignore' 'Aboart' 
	do
		case $choose in
		*root*)
			su -c "$0 force"
			[ $? == 0 ] && break
			;;
		*sudo*)
			sudo $0 force
			[ $? == 0 ] && break
			;;
		Try*)
			eval $0 force
			[ $? == 0 ] && break
			;;
		Ignore)
			exit 0
			;;
		Aboart)
			exit 1
			;;
		*)
			echo "Invalid select, please try again!" >&2
			continue
			;;
		esac

		echo "Install cross tools failed!" >&2
	done

	exit 0
fi

mkdir -pv $TOP_DIR
[ $? != 0 ] && exit 1

if [ -d $TOOL_DIR ]
then
	echo "Delete exist directory..." >&2
	rm $TOOL_DIR -rf 
else
	mkdir -pv $TOOL_DIR
fi

echo "Extract cross tools ..." >&2
tar -xjf $TOOLS_PKG -C $TOP_DIR
[ $? != 0 ] && exit 1


# creat link
rm $TAR_BIN_DIR -rf
mkdir -p $TAR_BIN_DIR
for armlinux in $BIN_FILES
do
       ln $armlinux $TAR_BIN_DIR/$LN_FILE_NAME`basename $armlinux | cut -b 34-` -sv
done

sed -i  '/\/arm-hisiv300-linux\//d' /etc/profile
[ $? != 0 ] && exit 1

if [ -z "`grep "$TAR_BIN_DIR" < /etc/profile`" ] ;
then
	echo "export path $TAR_BIN_DIR" >&2
	cat >> /etc/profile << EOF

# `date`
# Hisilicon Linux, Cross-Toolchain PATH
export PATH="$TAR_BIN_DIR:\$PATH" 
# 

EOF
	[ $? != 0 ] && exit 1
else
	echo "skip export toolchains path" >&2
fi

exit 0
```



### 编译UBoot（版本2010.06）

```bash
export ARCH=arm 
export CROSS_COMPILE=arm-hisiv300-linux-uclibcgnueabi-
make hi3518ev200_config#配置板卡
make#开始编译
dd if=u-boot.bin of=fb1 bs=1 count=64
dd if=reg_info_hi3518ev200.reg of=fb2 bs=4096 conv=sync
dd if=u-boot.bin of=fb3 bs=1 skip=4160
cat fb1 fb2 fb3 > uboot.3518ev200#最终生成的这个uboot.3518ev200文件为可以烧到板子上面运行
rm -f fb1 fb2 fb3
```

####测试U-Boot

```bash
set serverip 192.168.1.100#设置tftp服务器ip地址
set ipaddr 192.168.1.10#设置目标板卡ip地址
tftp 0x82000000 uboot.3518ev200#下载uboot二进制到内存指定位置
go 0x82000000#从内存指定位置运行程序
```



### 编译Linux内核（版本3.4.35）

```bash
export ARCH=arm 
export CROSS_COMPILE=arm-hisiv300-linux-uclibcgnueabi-
make hi3518ev200_full_defconfig
make menuconfig
make uImage
cp ./arch/arm/boot/uImage ./uImage
```



### 制作根文件系统

```bash
./mkfs.jffs2 -d ./rootfs -l -e 0x10000 -o rootfs-ov9732.jffs2
```



### 烧写

> SPI Flash地址空间分配:
>
>     |     512k   |      1792K    |      14080K           |
>     |------------|---------------|-----------------------|
>     |    boot    |     kernel    |     rootfs            |
> 板子上电时按住`crtl+c`，进入uboot命令行终端

1. 烧写内核

   ```bash
   set serverip 192.168.1.199;#设置tftp服务器端的IP地址
   mw.b 0x82000000 0xFF 0x1C0000;
   tftp 0x82000000 uImage;
   sf probe 0;
   sf erase 0x80000 0x1C0000;
   sf write 0x82000000 0x80000 0x1C0000
   ```

2. 烧写文件系统

   ```bash
   mw.b 0x82000000 0xFF 0xdc0000;
   tftp 0x82000000 rootfs-ov9732.jffs2;
   sf probe 0;
   sf erase 0x240000 0xdc0000;
   sf write 0x82000000 0x240000 0xdc0000
   ```

3. 配置uboot启动参数和启动命令

   ```bash
   setenv bootargs 'mem=32M console=ttyAMA0,115200 root=/dev/mtdblock2 rootfstype=jffs2 mtdparts=hi_sfc:512K(boot),1792K(kernel),14080K(rootfs)';
   setenv bootcmd 'sf probe 0;sf read 0x82000000 0x80000 0x1C0000;bootm 0x82000000';
   saveenv;
   reset
   ```



### tf卡操作

```bash
mkdir /sdcard#建立一个tf卡的挂载目录 
mount -t vfat /dev/mmcblk0p1 /sdcard#挂载
umount /sdcard#卸载
mkfs.vfat /dev/mmcblk0p1#格式化
```

