# Diagnostic only, for the private disposable VM started with BRIDGE_GDB=1.
# Set $entry_seg and $entry_ip to the trampoline's CS and linked _cstart_ IP.
set pagination off
set confirm off
python
import gdb

seg = int(gdb.parse_and_eval('$entry_seg'))
ip = int(gdb.parse_and_eval('$entry_ip'))

def reg(name):
    return int(gdb.parse_and_eval('$' + name))

def say(text):
    gdb.write(text + '\n')
    gdb.flush(gdb.STDOUT)

def run_to(cs, offset):
    gdb.execute('delete breakpoints', to_string=True)
    gdb.execute('hbreak *0x%x' % ((cs << 4) + offset), to_string=True)
    for ignored in range(20000):
        gdb.execute('continue', to_string=True)
        if reg('cs') == cs and reg('eip') == offset:
            return
        # GDB presents EIP rather than CS:EIP in v86 mode. A breakpoint can
        # also match another segment at the same linear address during boot.
        gdb.execute('delete breakpoints', to_string=True)
        gdb.execute('stepi', to_string=True)
        gdb.execute('hbreak *0x%x' % ((cs << 4) + offset), to_string=True)
    raise gdb.GdbError('entry not reached after 20000 breakpoint hits')

gdb.execute('monitor system_reset', to_string=True)
run_to(seg, 0x10)
say('trampoline entry reached')
run_to(seg, ip)
gdb.execute('delete breakpoints', to_string=True)
for step in range(180):
    cs, pc = reg('cs'), reg('eip')
    raw = bytes(gdb.selected_inferior().read_memory((cs << 4) + pc, 6))
    say('%03d %04x:%04x %s AX=%04x BX=%04x CX=%04x DX=%04x DS=%04x ES=%04x SS:SP=%04x:%04x' %
        (step, cs, pc, raw.hex(), reg('eax') & 65535, reg('ebx') & 65535,
         reg('ecx') & 65535, reg('edx') & 65535, reg('ds'), reg('es'), reg('ss'), reg('esp') & 65535))
    if cs != seg:
        say('left startup code; inspect the last instruction and task context')
        break
    if raw[:2] == b'\xcd\x21':
        say('DOS CALL: waiting for return')
        run_to(cs, pc + 2)
        gdb.execute('delete breakpoints', to_string=True)
        say('DOS CALL RETURNED')
    elif raw[0] == 0xe8:
        say('near call reached; stop before stepping into runtime initializers')
        break
    else:
        gdb.execute('stepi', to_string=True)
end
detach
