/* Compiler smoke test for 16-bit Windows-compatible C objects. */
unsigned short calmira_drive_changed(unsigned short previous,
                                     unsigned short current)
{
    return previous != current;
}
