// SPDX-License-Identifier: GPL-3.0-or-later
// Inspect a locally supplied Win16 program. Generated decompiler output is
// for private analysis, not for inclusion in the project's implementation.
// @category Calmira.Analysis
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;
import ghidra.program.model.mem.MemoryBlock;
import ghidra.program.model.symbol.Symbol;
import ghidra.program.model.symbol.SymbolIterator;
import java.io.PrintWriter;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;

public class inspectwin16 extends GhidraScript {
    @Override
    public void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length != 1) throw new IllegalArgumentException("Expected output directory");
        Path directory = Path.of(args[0]);
        Files.createDirectories(directory);
        String base = currentProgram.getName();
        try (PrintWriter inventory = new PrintWriter(Files.newBufferedWriter(
                directory.resolve(base + ".inventory.txt"), StandardCharsets.UTF_8))) {
            inventory.println("Program: " + base);
            inventory.println("Format: " + currentProgram.getExecutableFormat());
            inventory.println("Language: " + currentProgram.getLanguageID());
            inventory.println("Libraries:");
            for (String name : currentProgram.getExternalManager().getExternalLibraryNames())
                inventory.println("  " + name);
            inventory.println("External symbols:");
            SymbolIterator external = currentProgram.getSymbolTable().getExternalSymbols();
            while (external.hasNext() && !monitor.isCancelled()) {
                Symbol symbol = external.next();
                inventory.println("  " + symbol.getName(true));
            }
            inventory.println("Functions:");
            FunctionIterator functions = currentProgram.getFunctionManager().getFunctions(true);
            while (functions.hasNext() && !monitor.isCancelled()) {
                Function function = functions.next();
                inventory.println(function.getEntryPoint() + " " + function.getName() +
                    " " + function.getSignature());
            }
        }
        DecompInterface decompiler = new DecompInterface();
        try {
            if (!decompiler.openProgram(currentProgram))
                throw new IllegalStateException(decompiler.getLastMessage());
            try (PrintWriter output = new PrintWriter(Files.newBufferedWriter(
                    directory.resolve(base + ".private-decompiled.c"), StandardCharsets.UTF_8))) {
                output.println("/* PRIVATE REFERENCE ONLY: not project source. */");
                int count = 0;
                FunctionIterator functions = currentProgram.getFunctionManager().getFunctions(true);
                while (functions.hasNext() && !monitor.isCancelled() && count < 16) {
                    Function function = functions.next();
                    String name = function.getName().toUpperCase(Locale.ROOT);
                    MemoryBlock block = currentProgram.getMemory().getBlock(function.getEntryPoint());
                    if (function.isExternal() || function.isThunk() || block == null ||
                        !block.isInitialized() || block.getName().equals("EXTERNAL")) continue;
                    if (!(name.contains("CBTPROC") ||
                        name.contains("CALLWNDPROC") || name.contains("OPENFILEHOOK") ||
                        name.contains("CREATESHORTNAME") || name.contains("SETLONGNAME") ||
                        name.contains("LFN_COMMIT") || name.contains("GETOPENFILENAME") ||
                        name.contains("LFN_FINDUNIQUE") || name.contains("LFN_INIT") ||
                        name.equals("IFA_INIT") || name.equals("EVENT_CREATE") ||
                        name.equals("EVENT_DESTROY") || name.equals("VIEWER_SHOW"))) continue;
                    count++;
                    output.println("\n/* " + function.getEntryPoint() + " " + name + " */");
                    DecompileResults result = decompiler.decompileFunction(function, 30, monitor);
                    if (result.decompileCompleted() && result.getDecompiledFunction() != null)
                        output.println(result.getDecompiledFunction().getC());
                    else output.println("/* Decompilation unavailable: " + result.getErrorMessage() + " */");
                }
                output.println("/* Selected functions: " + count + " */");
            }
        } finally {
            decompiler.dispose();
        }
    }
}
