# SUDA_3518之U-Boot走读

### 顶层Makefile

```makefile
MKCONFIG	:= $(SRCTREE)/mkconfig
export MKCONFIG
#清除上一次配置生成的文件
unconfig:
#@的作用是执行命令的时候不在shell中显示
#obj变量由编译命令make的-O参数指定，默认代表顶层目录
	@rm -f $(obj)include/config.h $(obj)include/config.mk \
		$(obj)board/*/config.tmp $(obj)board/*/*/config.tmp \
		$(obj)include/autoconf.mk $(obj)include/autoconf.mk.dep
#make hi3518ev200 = make hi3518ev200_config + make
%: %_config
	$(MAKE)
hi3518ev200_config: unconfig
	@$(MKCONFIG) $(@:_config=) arm hi3518ev200 hi3518ev200 NULL hi3518ev200
#$(@:_config=)就是将hi3518ev200_config中的_config字符串去掉，剩下hi3518ev200，后面的参数依次代表Target，Architecture，CPU，Board，Vendor，SoC
```

* mkconfig脚本最终会在**include**文件夹下生成`config.mk`文件，内容为：

  ```makefile
  ARCH   = arm
  CPU    = hi3518ev200
  BOARD  = hi3518ev200
  SOC    = hi3518ev200
  ```

* mkconfig脚本最终会在**include**文件夹下生成`config.h`文件，内容为：

  ```c
  /* Automatically generated - do not edit */
  #define CONFIG_BOARDDIR board/hi3518ev200
  #include <config_defaults.h>
  #include <configs/hi3518ev200.h>
  #include <asm/config.h>
  ```

* mkconfig脚本会**include**文件夹下生成软链接*asm*指向`arch/arm/include/asm`

* mkconfig脚本会在**include/asm**文件夹下生成软链接*arch*指向`include/asm/arch-hi3518ev200`

* mkconfig脚本会在**include/asm**文件夹下生成软链接*proc*指向`include/asm/proc-armv`



```makefile
HOSTARCH := $(shell uname -m | \
	sed -e s/i.86/i386/ \
	    -e s/sun4u/sparc64/ \
	    -e s/arm.*/arm/ \
	    -e s/sa110/arm/ \
	    -e s/ppc64/powerpc/ \
	    -e s/ppc/powerpc/ \
	    -e s/macppc/powerpc/)
#HOSTARCH为x86_64

HOSTOS := $(shell uname -s | tr '[:upper:]' '[:lower:]' | \
	    sed -e 's/\(cygwin\).*/cygwin/')
#HOSTOS为linux

SHELL := $(shell if [ -x "$$BASH" ]; then echo $$BASH; \
	else if [ -x /bin/bash ]; then echo /bin/bash; \
	else echo sh; fi; fi)
#SHELL为/bin/bash
export	HOSTARCH HOSTOS SHELL
```



```makefile
#sinclude表示后面的内容如果存在，就包含进来；如果不存在，就作为目标去创建
sinclude $(obj)include/autoconf.mk.dep
sinclude $(obj)include/autoconf.mk

$(obj)include/autoconf.mk.dep: $(obj)include/config.h include/common.h
	@$(XECHO) Generating $@ ; \
	set -e ; \
	: Generate the dependancies ; \
	$(CC) -x c -DDO_DEPS_ONLY -M $(HOSTCFLAGS) $(CPPFLAGS) \
		-MQ $(obj)include/autoconf.mk include/common.h > $@
#-MQ的作用：编译器将生成依赖关系include/autoconf.mk:include/common.h，并将最终结果输出到include/autoconf.mk.dep文件中

$(obj)include/autoconf.mk: $(obj)include/config.h
	@$(XECHO) Generating $@ ; \
	set -e ; \
	: Extract the config macros ; \
	$(CPP) $(CFLAGS) -DDO_DEPS_ONLY -dM include/common.h | \
		sed -n -f tools/scripts/define2mk.sed > $@.tmp && \
	mv $@.tmp $@
#-dM的作用:编译器提取include/common.h中定义的宏
```

* `set -e`通知bash如果下面任何语句的执行结果不是0，整个脚本就会立即退出
* **toos/scripts/define2mk.sed**脚本主要完成在`include/common.h`中查找和处理以"CONFIG_"开头的宏定义
* `include/autoconf.mk`实质上就是`configs/hi3518ev200.h`和`asm/config.h`两个文件中以CONFIG_开头的宏定义进行处理的结果
* `include/autoconf.mk.dep`里面是autoconf.mk依赖的头文件



```makefile
#引入make hi3518ev200_config后产生的config.mk文件
include $(obj)include/config.mk
export	ARCH CPU BOARD VENDOR SOC

#引入顶层目录下的config.mk文件
include $(TOPDIR)/config.mk
```

* 顶层目录下的`config.mk`主要控制编译选项和规则

  ```makefile
  AS	= $(CROSS_COMPILE)as
  LD	= $(CROSS_COMPILE)ld
  CC	= $(CROSS_COMPILE)gcc
  CPP	= $(CC) -E
  AR	= $(CROSS_COMPILE)ar
  NM	= $(CROSS_COMPILE)nm
  LDR	= $(CROSS_COMPILE)ldr
  STRIP	= $(CROSS_COMPILE)strip
  OBJCOPY = $(CROSS_COMPILE)objcopy
  OBJDUMP = $(CROSS_COMPILE)objdump
  RANLIB	= $(CROSS_COMPILE)RANLIB

  sinclude $(OBJTREE)/include/autoconf.mk#包含所有板级配置
  CPUDIR=arch/$(ARCH)/cpu/$(CPU)
  sinclude $(TOPDIR)/arch/$(ARCH)/config.mk#定义了CROSS_COMPILE和LDSCRIPT
  sinclude $(TOPDIR)/$(CPUDIR)/config.mk#添加了一些PLATFORM_RELFLAGS参数
  sinclude $(TOPDIR)/board/$(BOARDDIR)/config.mk#定义了TEXT_BASE的值为0x80800000

  CPPFLAGS += -I$(TOPDIR)/include#指定了头文件的路径

  CFLAGS := $(CPPFLAGS) -Wall -Wstrict-prototypes

  LDFLAGS += -Bstatic -T $(obj)u-boot.lds $(PLATFORM_LDFLAGS)#Bstatic表示使用静态方式链接，并制定链接脚本文件
  LDFLAGS += -Ttext $(TEXT_BASE)#指定代码段的起始地址

  export	HOSTCC HOSTCFLAGS HOSTLDFLAGS PEDCFLAGS HOSTSTRIP CROSS_COMPILE \
  	AS LD CC CPP AR NM STRIP OBJCOPY OBJDUMP MAKE
  export	TEXT_BASE PLATFORM_CPPFLAGS PLATFORM_RELFLAGS CPPFLAGS CFLAGS AFLAGS
  ```



```makefile
ALL += $(obj)u-boot.bin $(obj)System.map
all:		$(ALL)

$(obj)u-boot.bin:	$(obj)u-boot
		$(OBJCOPY) ${OBJCFLAGS} -O binary $< $@

SYSTEM_MAP = \
		$(NM) $1 | \
		grep -v '\(compiled\)\|\(\.o$$\)\|\( [aUw] \)\|\(\.\.ng$$\)\|\(LASH[RL]DI\)' | \
		LC_ALL=C sort
$(obj)System.map:	$(obj)u-boot
		@$(call SYSTEM_MAP,$<) > $(obj)System.map

GEN_UBOOT = \
		UNDEF_SYM=`$(OBJDUMP) -x $(LIBBOARD) $(LIBS) | \
		sed  -n -e 's/.*\($(SYM_PREFIX)__u_boot_cmd_.*\)/-u\1/p'|sort|uniq`;\
		cd $(LNDIR) && $(LD) $(LDFLAGS) $$UNDEF_SYM $(__OBJS) \
			--start-group $(__LIBS) --end-group $(PLATFORM_LIBS) \
			-Map u-boot.map -o u-boot
#--start-group和--end-group指定了一组需要链接的库文件,-Map产生符号表u-boot.map

$(obj)u-boot:	ddr_training depend $(SUBDIRS) $(OBJS) $(LIBBOARD) $(LIBS) $(LDSCRIPT) $(obj)u-boot.lds
		$(GEN_UBOOT)
		
ddr_training:
	touch $(TOPDIR)/drivers/ddr/ddr_cmd_loc.S
	make -C $(TOPDIR)/drivers/ddr/cmd_bin \
		TOPDIR=$(TOPDIR) \
		CROSS_COMPILE=$(CROSS_COMPILE)

depend dep:	$(TIMESTAMP_FILE) $(VERSION_FILE) $(obj)include/autoconf.mk
		for dir in $(SUBDIRS) $(CPUDIR) $(dir $(LDSCRIPT)) ; do \
			$(MAKE) -C $$dir _depend ; done

#将LDSCRIPT指定路径下的链接脚本文件进行简单的预处理后输出到目标路径下的u-boot.lds文件中
$(obj)u-boot.lds: $(LDSCRIPT)
		$(CPP) $(CPPFLAGS) $(LDPPFLAGS) -ansi -D__ASSEMBLY__ -P - <$^ >$@
```



