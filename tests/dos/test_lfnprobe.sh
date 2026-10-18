#!/bin/bash
set -uo pipefail

project_root=$(cd "$(dirname "$0")/../.." && pwd)
boot_image=${BOOTIMG:-$HOME/Iso/Dos/dos71de/Dos7.1_System_deutsch.IMG}
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

cp "$boot_image" "$work_dir/boot.img"
chmod u+w "$work_dir/boot.img"
printf 'org 100h\nmov dx,501h\nout dx,al\nint 20h\n' > "$work_dir/qexit.asm"
nasm -f bin -o "$work_dir/QEXIT.COM" "$work_dir/qexit.asm"
printf '@ECHO OFF\r\nA:\\LFNPROBE.EXE A: > AUX\r\nA:\\QEXIT.COM\r\n' > "$work_dir/AUTOEXEC.BAT"
mcopy -o -i "$work_dir/boot.img" \
	"$project_root/build/dos/lfn/LFNPROBE.EXE" "$work_dir/QEXIT.COM" ::/
mcopy -o -i "$work_dir/boot.img" "$work_dir/AUTOEXEC.BAT" ::/

{
	sleep 8
	echo quit
} | qemu-system-i386 -machine pc -accel kvm -m 16 -display none \
	-monitor stdio -drive if=floppy,format=raw,file="$work_dir/boot.img" \
	-boot a -nic none -serial file:"$work_dir/serial.log" \
	-device isa-debug-exit,iobase=0x501,iosize=0x02 > "$work_dir/monitor.log" 2>&1

tr -d '\r' < "$work_dir/serial.log"
grep -q 'DOS=7.10 drive=A:' "$work_dir/serial.log"
echo "LFN probe DOS test passed"
