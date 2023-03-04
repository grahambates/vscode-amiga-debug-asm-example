source = main.asm
program = out/a

ELF2HUNK =  elf2hunk
VASM = vasmm68k_mot
CC = m68k-amiga-elf-gcc

CCFLAGS = -g -MP -MMD -m68000 -Ofast -nostdlib -Wextra -Wno-unused-function -Wno-volatile-register-var -fomit-frame-pointer -fno-tree-loop-distribution -flto -fwhole-program -fno-exceptions
LDFLAGS = -Wl,--emit-relocs,-Ttext=0,-Map=$(program).map
VASMFLAGS = -m68000 -Felf -dwarf=3 -quiet -x -DDEBUG=1

all: $(program).exe

$(program).exe: $(program).elf
	$(info Elf2Hunk $(@))
	$(ELF2HUNK) $< $@ -s -v

$(program).o: $(source)
	$(info Assembling $<)
	$(VASM) $(VASMFLAGS) -o $@ $<

$(program).elf: $(program).o
	$(info Linking $<)
	$(CC) $(CCFLAGS) $(LDFLAGS) $< -o $@

$(program).d: $(source)
	$(info Building dependencies for $<)
	$(VASM) $(VASMFLAGS) -depend=make -quiet -o $(program).elf $< > $@

-include $(program).d

clean:
	$(info Cleaning...)
	$(RM) out/*.*

.PHONY: rundist dist all clean