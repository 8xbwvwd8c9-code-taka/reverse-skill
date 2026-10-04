// Bounded evidence-only Ghidra script for L850.
// @category L850
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;
import ghidra.program.model.symbol.Reference;
import java.io.File;
import java.io.PrintWriter;

public class L850BoundedWindow extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 3) {
            throw new IllegalArgumentException("usage: L850BoundedWindow <startVA> <endVA> <outputFile>");
        }
        Address start = toAddr(Long.decode(args[0]));
        Address end = toAddr(Long.decode(args[1]));
        File out = new File(args[2]);
        out.getParentFile().mkdirs();

        try (PrintWriter pw = new PrintWriter(out, "UTF-8")) {
            pw.println("STATUS=PASS");
            pw.println("PROGRAM=" + currentProgram.getName());
            pw.println("IMAGE_BASE=" + currentProgram.getImageBase());
            pw.println("WINDOW_START=" + start);
            pw.println("WINDOW_END=" + end);

            Function f = getFunctionContaining(start);
            if (f != null) {
                pw.println("FUNCTION=" + f.getName());
                pw.println("FUNCTION_ENTRY=" + f.getEntryPoint());
            } else {
                pw.println("FUNCTION=NONE");
            }

            InstructionIterator it = currentProgram.getListing().getInstructions(start, true);
            int count = 0;
            while (it.hasNext()) {
                monitor.checkCancelled();
                Instruction ins = it.next();
                if (ins.getAddress().compareTo(end) >= 0) break;
                byte[] bytes = ins.getBytes();
                pw.printf("%s | %-24s | %s%n", ins.getAddress(), bytes == null ? "" : bytesToHex(bytes), ins.toString());
                for (Reference r : ins.getReferencesFrom()) {
                    pw.println("  REF_FROM -> " + r.getToAddress() + " [" + r.getReferenceType() + "]");
                }
                count++;
            }
            pw.println("INSTRUCTION_COUNT=" + count);

            Reference[] refs = getReferencesTo(start);
            pw.println("REFS_TO_START=" + refs.length);
            for (Reference r : refs) {
                pw.println("REF_TO_START=" + r.getFromAddress() + " [" + r.getReferenceType() + "]");
            }
        }
    }

    private static String bytesToHex(byte[] data) {
        StringBuilder sb = new StringBuilder();
        for (byte b : data) {
            if (sb.length() > 0) sb.append(' ');
            sb.append(String.format("%02X", b & 0xff));
        }
        return sb.toString();
    }
}
