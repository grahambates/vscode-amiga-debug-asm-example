# Amiga Debug - assembly example

Example assembly project for Bartman's [Amiga Debug](https://github.com/BartmanAbyss/vscode-amiga-debug) VS Code extension.

This is a port of the C/C++ project template bundled with the extension, to pure m68k assembly. This demonstrates how you can use the extension without C, and still take advantage of the profiler and debugging tools.

The Makefile uses vasm to assemble the source to ELF output format and just uses GCC for linking. Elf2hunk then converts this to a hunk executable.

Many of the C support functions are converted to assembly macros. These can be found in `include/debug.i`. This includes:

- Toggling CPU idle mode
- Overlay graphics / text
- Registering graphics resources

The following are not yet ported:

- KPrintF
- warpmode