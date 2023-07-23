
#!/bin/bash
#
# Compile script for Linux (Droidian on the Redmi Note 8)
SECONDS=0 # builtin bash timer
KERNEL_PATH=$PWD
export TC_DIR="$HOME/tc/clang-14.0.0"
export PATH="$TC_DIR:$PATH"
#GCC_64_DIR="$HOME/tc/aarch64-linux-android-4.9"
#GCC_32_DIR="$HOME/tc/arm-linux-androideabi-4.9"
#AK3_DIR="$HOME/tc/AnyKernel3"
DEFCONFIG="vendor/ginkgo-perf_defconfig"
export PATH="$TC_DIR/bin:$PATH"
# Detect if the system has SMT enabled or not.
if [ "$(cat /sys/devices/system/cpu/smt/active)" = "1" ]; then
		export THREADS=$(($(nproc --all) * 2))
	else
		export THREADS=$(nproc --all)
	fi
# Detect the amount of system memory.
export SYSMEM="$(vmstat -s | grep -i 'total memory' | sed 's/ *//')"

# Install needed tools
if [[ $1 = "-t" || $1 = "--tools" ]]; then
	git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 $HOME/tc/aarch64-linux-android-4.9
	git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 $HOME/tc/arm-linux-androideabi-4.9
        wget https://gitlab.com/David112x/clang/-/archive/14.0.0/clang-14.0.0.tar.gz -O $HOME/tc/clang-14.0.0.tar.gz && tar xvf $HOME/tc/clang-14.0.0.tar.gz -C $HOME/tc/
	touch $HOME/tc/clang-14.0.0/AndroidVersion.txt && echo -e "14.0.0" | sudo tee -a $HOME/tc/clang-14.0.0/AndroidVersion.txt > /dev/null 2>&1
fi

# Regenerate defconfig file
if [[ $1 = "-r" || $1 = "--regen" ]]; then
	make O=out ARCH=arm64 $DEFCONFIG savedefconfig
	cp out/defconfig arch/arm64/configs/$DEFCONFIG
	echo -e "\nSuccessfully regenerated defconfig at $DEFCONFIG"
fi

# Make a clean build
if [[ $1 = "-c" || $1 = "--clean" ]]; then
	rm -rf out
fi

if [[ $1 = "-b" || $1 = "--build" ]]; then
# Environment variables for the build.
	#export CROSS_COMPILE=$GCC_64_DIR/bin/aarch64-linux-android-
	#export CROSS_COMPILE_ARM32=$GCC_32_DIR/bin/arm-linux-androideabi-
	export CLANG_TRIPLE=aarch64-linux-gnu-
	export ARCH=arm64
	export CROSS_COMPILE=aarch64-linux-gnu-
	export LD_LIBRARY_PATH=$TC_DIR/lib
	export KBUILD_BUILD_USER="David112x"
	export KBUILD_BUILD_HOST="$(hostname)"
	export USE_HOST_LEX=yes
	mkdir -p out
# Make defconfig
	make $DEFCONFIG -j$THREADS CC=clang LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip O=out

# Make kernel
	echo The system has $SYSMEM...
	echo Using $THREADS jobs for this build...
	make -j$THREADS O=out CC="ccache clang -Qunused-arguments -fcolor-diagnostics" LLVM=1 LD=ld.lld LLVM_IAS=1 AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip Image.gz dtbo.img

	kernel="out/arch/arm64/boot/Image.gz"
	dtb="arch/arm64/boot/dts/xiaomi/qcom-base/trinket.dtb"
	dtbo="out/arch/arm64/boot/dtbo.img"

	if [ -f "$kernel" ] && [ -f "$dtbo" ]; then
		rm *.zip 2>/dev/null
		# Set kernel name and version
		KERNELVERSION="$(cat $KERNEL_PATH/Makefile | grep VERSION | head -n 1 | sed "s|.*=||1" | sed "s| ||g")"
		KERNELPATCHLEVEL="$(cat $KERNEL_PATH/Makefile | grep PATCHLEVEL | head -n 1 | sed "s|.*=||1" | sed "s| ||g")"
		KERNELSUBLEVEL="$(cat $KERNEL_PATH/Makefile | grep SUBLEVEL | head -n 1 | sed "s|.*=||1" | sed "s| ||g")"
		REVISION=v$KERNELVERSION.$KERNELPATCHLEVEL.$KERNELSUBLEVEL
		ZIPNAME=""$REVISION"-Droidian-RedmiNote8-$(date '+%Y%m%d-%H%M').zip"
		echo -e ""
		echo -e ""
		echo -e "********************************************"
		echo -e "\nKernel compiled succesfully! Zipping up...\n"
		echo -e "********************************************"
		echo -e ""
		echo -e ""
	if [ -d "$AK3_DIR" ]; then
		cp -r $AK3_DIR AnyKernel3
	elif ! git clone -q https://github.com/David112x/AnyKernel3 ; then
			echo -e "\nAnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting..."
	fi
		cp $kernel $dtbo AnyKernel3
		#cp $dtb AnyKernel3/dtb
		rm -rf out/arch/arm64/boot
		cd AnyKernel3
		#git checkout surya &> /dev/null
		zip -r9 "../$ZIPNAME" * -x .git README.md *placeholder
		cd ..
		rm -rf AnyKernel3

	# Upload to SourceForge, only works if you use -b -s
        if [[ $2 = "-s" || $2 = "--share" ]]; then
                CHAT_ID="Put here" # ChatID
                API="Put here" # API bot token
                IMAGE="Put URL image"

                curl \
                -F chat_id="$CHAT_ID" \
                -F "parse_mode=Markdown" \
                -F caption="Put your changelog here and link in mardkdown style" \
                -F photo="$IMAGE" \
                https://api.telegram.org/bot"$API"/sendPhoto
        fi

        echo -e ""
        echo -e ""
        echo -e "************************************************************"
        echo -e "**                                                        **"
        echo -e "**   File name: $ZIPNAME   **"
        echo -e "**   Build completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s)!    **"
        echo -e "**                                                        **"
        echo -e "************************************************************"
        echo -e ""
        echo -e ""
	else
        echo -e ""
        echo -e ""
        echo -e "*****************************"
        echo -e "**                         **"
        echo -e "**   Compilation failed!   **"
        echo -e "**                         **"
        echo -e "*****************************"
	fi
	fi
