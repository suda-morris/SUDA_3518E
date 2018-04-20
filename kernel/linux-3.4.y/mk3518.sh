make clean
cp hi3518ev200_qddytt .config
make uImage
cp ./arch/arm/boot/uImage ./uImage
