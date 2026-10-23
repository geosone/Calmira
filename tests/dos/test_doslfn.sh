#!/bin/bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/../.." && pwd)
boot_image=${BOOTIMG:-$HOME/Iso/Dos/dos71de/Dos7.1_System_deutsch.IMG}
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

for tool in mcopy nasm qemu-system-i386; do
	command -v "$tool" >/dev/null || {
		echo "Missing test tool: $tool" >&2
		exit 1
	}
done
test -f "$boot_image" || {
	echo "Set BOOTIMG to a bootable MS-DOS 7.1 floppy image" >&2
	exit 1
}

run_driver_test()
{
	driver=$1
	image="$work_dir/${driver}.img"
	serial="$work_dir/${driver}.log"
	cp "$boot_image" "$image"
	chmod u+w "$image"
	printf 'FILES=30\r\nBUFFERS=20\r\n' > "$work_dir/CONFIG.SYS"
	printf '@ECHO OFF\r\nA:\\LFNPROBE.EXE A: > AUX\r\nA:\\%s.COM\r\nA:\\LFNPROBE.EXE A: > AUX\r\nA:\\QEXIT.COM\r\n' \
		"$driver" > "$work_dir/AUTOEXEC.BAT"
	mcopy -o -i "$image" \
		"$project_root/build/dos/lfn/LFNPROBE.EXE" \
		"$project_root/build/dos/doslfn/${driver,,}.com" \
		"$project_root/build/dos/doslfn/cp850uni.tbl" \
		"$work_dir/QEXIT.COM" ::/
	mcopy -o -i "$image" "$work_dir/AUTOEXEC.BAT" "$work_dir/CONFIG.SYS" ::/

	set +e
	{
		sleep 8
		echo quit
	} | qemu-system-i386 -machine pc -accel "${QEMU_ACCEL:-tcg}" -m 16 -display none \
		-monitor stdio -drive if=floppy,format=raw,file="$image" \
		-boot a -nic none -serial file:"$serial" \
		-device isa-debug-exit,iobase=0x501,iosize=0x02 \
		> "$work_dir/${driver}.monitor.log" 2>&1
	set -e

	tr -d '\r' < "$serial"
	grep -q 'DOS=7.10 drive=A: LFN=no' "$serial"
	if grep -q 'LFN=no filesystem=FAT32' "$serial"; then
		echo "FAT12 floppy was incorrectly detected as FAT32" >&2
		exit 1
	fi
	grep -q 'DOS=7.10 drive=A: LFN=yes filesystem=FAT' "$serial"
}

printf 'org 100h\nmov dx,501h\nxor ax,ax\nout dx,al\nint 20h\n' > "$work_dir/qexit.asm"
nasm -f bin -o "$work_dir/QEXIT.COM" "$work_dir/qexit.asm"

run_driver_test DOSLFNMS
run_driver_test DOSLFN
echo "DOSLFN TSR tests passed"
