/* lfnprobe.c - report DOS LFN and FAT32 capabilities for installer policy
 * Copyright (C) 2026 GeosOne.  GNU General Public License version 3. */

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <dos.h>
#include <i86.h>

static int volume_info( const char *root, char *filesystem,
	unsigned short *flags )
{
	union REGS inregs, outregs;
	struct SREGS segments;

	memset( &inregs, 0, sizeof(inregs) );
	memset( &outregs, 0, sizeof(outregs) );
	memset( filesystem, 0, 16 );
	segread( &segments );
	inregs.x.ax = 0x71A0;
	inregs.x.cx = 16;
	inregs.x.dx = FP_OFF( root );
	inregs.x.di = FP_OFF( filesystem );
	segments.ds = FP_SEG( root );
	segments.es = FP_SEG( filesystem );
	intdosx( &inregs, &outregs, &segments );
	if ( outregs.x.cflag || outregs.x.ax == 0x7100 )
		return 0;
	*flags = outregs.x.bx;
	return 1;
}

static void dos_version( unsigned char *major, unsigned char *minor )
{
	union REGS regs;
	memset( &regs, 0, sizeof(regs) );
	regs.h.ah = 0x30;
	intdos( &regs, &regs );
	*major = regs.h.al;
	*minor = regs.h.ah;
}

/* DOS 7 extended DPB.  The maximum-cluster DWORD starts at offset 45 in
 * the 3F-byte structure.  Unlike AX=71A0, this does not require an LFN
 * provider and can therefore identify a bare MS-DOS 7.1 FAT32 volume. */
static int is_fat32( char drive )
{
	union REGS inregs, outregs;
	struct SREGS segments;
	unsigned char dpb[0x3F];
	unsigned long maximum_cluster;

	memset( &inregs, 0, sizeof(inregs) );
	memset( &outregs, 0, sizeof(outregs) );
	memset( dpb, 0, sizeof(dpb) );
	segread( &segments );
	inregs.x.ax = 0x7302;
	inregs.h.dl = (unsigned char)( toupper( (unsigned char)drive ) - 'A' + 1 );
	inregs.x.cx = sizeof(dpb);
	inregs.x.di = FP_OFF( dpb );
	segments.es = FP_SEG( dpb );
	intdosx( &inregs, &outregs, &segments );
	if ( outregs.x.cflag )
		return 0;
	memcpy( &maximum_cluster, dpb + 45, sizeof(maximum_cluster) );
	return maximum_cluster >= 65525UL;
}

int main( int argc, char **argv )
{
	char root[4] = "C:\\", filesystem[16];
	unsigned short flags = 0;
	unsigned char major, minor;
	int quiet = 0, mode = 0, available, fat32, i;

	for ( i = 1; i < argc; i++ ) {
		if ( !stricmp( argv[i], "/Q" ) )
			quiet = 1;
		else if ( !stricmp( argv[i], "/LFN" ) )
			mode = 1;
		else if ( !stricmp( argv[i], "/FAT32" ) )
			mode = 2;
		else if ( !stricmp( argv[i], "/DOS71" ) )
			mode = 3;
		else if ( isalpha( (unsigned char)argv[i][0] ) && argv[i][1] == ':' )
			root[0] = (char)toupper( (unsigned char)argv[i][0] );
		else {
			if ( !quiet )
				puts( "Usage: LFNPROBE [/Q] [/LFN|/FAT32|/DOS71] [drive:]" );
			return 2;
		}
	}
	dos_version( &major, &minor );
	available = volume_info( root, filesystem, &flags );
	fat32 = is_fat32( root[0] );
	if ( !quiet ) {
		printf( "DOS=%u.%02u drive=%c: LFN=%s", major, minor, root[0],
			available && ( flags & 0x4000 ) ? "yes" : "no" );
		if ( available )
			printf( " filesystem=%s", filesystem );
		else if ( fat32 )
			printf( " filesystem=FAT32" );
		putchar( '\n' );
	}
	if ( mode == 1 )
		return available && ( flags & 0x4000 ) ? 0 : 1;
	if ( mode == 2 )
		return fat32 ? 0 : 1;
	if ( mode == 3 )
		return major > 7 || ( major == 7 && minor >= 10 ) ? 0 : 1;
	return available && ( flags & 0x4000 ) ? 0 : 1;
}
