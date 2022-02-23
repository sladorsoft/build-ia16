# New ELF i386 relocation types to support 16-bit x86 segmented addressing

(TK Chia — 21 Feb 2022 version)

The new ELF i386<sup>[1][2][3]</sup> relocations described below have been implemented in the main branch of my fork of GNU Binutils,<sup>[4]</sup> and are also partially supported by my fork of GCC.<sup>[5]</sup>  They allow one to use ELF i386 as an intermediate object format, to support the linking of 16-bit x86<sup>[6]</sup> programs whose code and data may span multiple segments.

The older LMA ≠ VMA relocation scheme is currently the default when building for the MS-DOS — as of writing, some programs such as the FreeDOS kernel<sup>[7]</sup> still assume it.  It has some limitations.  I am experimenting with using Anvin's `segelf` relocation scheme for the Embeddable Linux Kernel Subset (ELKS)<sup>[8]</sup> project.

## Discussion: modelling IA-16 segments in GNU Binutils

In IA-16 segmented code, program memory is grouped into _segments_, each segment being a contiguous slice of the system's flat address space.  Each memory item is addressed as an _offset_ into a segment which contains it: thus, a Segment(_S_)`:`Offset(_S_) pair.  There are at least two general ways to model Segment`:`Offset addressing under ELF.

### LMA ≠ VMA relocation scheme

Binutils's binary file descriptor (BFD) engine allows each output segment to have both a _virtual address_ (VMA) and a _load address_ (LMA).  This gives rise to a simplistic way to represent separate IA-16 segments: as output segments in BFD with distinct LMAs but overlapping VMAs (corresponding to in-segment offsets).

An instruction and relocation sequence to load a far pointer to a variable `foo` in `%dx:%ax` might look like this:

       0:	b8 00 00             	mov    $0x0,%ax
    			1: R_386_16	foo
       3:	ba 00 00             	mov    $0x0,%dx
    			4: R_386_OZSEG16	foo

Due to the current limitations of the Binutils linker script syntax, programs that use this relocation scheme cannot have an arbitrarily large number of output IA-16 segments.

### New `segelf` relocation scheme

H. Peter Anvin has proposed a different Segment`:`Offset modelling scheme<sup>[9]</sup> (_q. v._ for more information).  This scheme relies only on VMAs.  In this scheme, for each symbol _S_, there should be a matching symbol _S_`!` giving the VMA of _S_'s IA-16 segment base.

An instruction and relocation sequence to load a far pointer to a variable `foo` in `%dx:%ax` might look like this:

       0:	b8 00 00             	mov    $0x0,%ax
    			1: R_386_16	foo
    			1: R_386_SUB16	foo!
       3:	ba 00 00             	mov    $0x0,%dx
    			4: R_386_SEG16	foo!

To support this scheme:

  * The Binutils assembler is modified so that, whenever a program defines (say) a label `foo` in a section `.data`, it can automatically create a corresponding "segment base" label `foo!` in a "segment base" section `.data!`.  The `.data!` segment should always have a size of zero.
  * Also, to potentially support linking protected-mode programs, the assembler can also create a label `.foo&` and section `.data&`<sup>[10]</sup> to mark the end of the IA-16 segment that `foo` resides in.
			
This scheme is currently the default when targeting ELKS (`ia16-elf-gcc -melks` …) and when targeting MS-DOS in DOS extender mode (`ia16-elf-gcc -mdosx` …).  It can also be enabled

  * in the assembler with `ia16-elf-as --32-segelf` …
  * or in GCC with `ia16-elf-gcc -msegelf` … .

**Note**: the real-mode MS-DOS platform libraries and real-mode `libgcc` have not been set up to use this scheme, so you may need to recompile them.

## The new relocation types

Relocation type name   | Value | Field  | Calculation                     | Remarks
---------------------- | :---: | :----: | ------------------------------- | :------
`R_386_SEG16`          |   45  | word16 | _M_((_A_ `<<` 4) + _S_)         | Used by Anvin's `segelf` scheme
`R_386_SUB16`          |   46  | word16 | _A_ - _S_                       | Used by Anvin's `segelf` scheme
`R_386_SUB32`          |   47  | word32 | _A_ - _S_                       | Used by Anvin's `segelf` scheme
`R_386_SEGRELATIVE`    |   48  | word16 | _M_((_A_ `<<` 4) + _B_)         | Used by Anvin's `segelf` scheme
`R_386_OZSEG16`        |   80  | word16 | _A_ + _M_(_Z_(_S_))             | Used by the LMA ≠ VMA scheme
`R_386_OZRELSEG16`     |   81  | word16 | _A_ + ((_Z_(_S_) - _B_) `>>` 4) | Used by the LMA ≠ VMA scheme

Definitions:

  * _A_, _S_: the addend and symbol value for the relocation, per the original ELF specification.<sup>[1]</sup>
  * _B_: the flat address — known only at program run time — where the first byte of the program will be loaded.
  * _Z_(_S_): the runtime linear address for "IA-16 offset 0" in _S_'s output section _X_.
  * _M_(·): a function to map a segment base address to a segment register value.  For a program which will run in x86 real mode,<sup>[11]</sup> this will simply shift the address right by 4 bits.

An `R_386_OZSEG16` or `R_386_SEG16` basically corresponds to a segment relocation in an MS-DOS `MZ`<sup>[12]</sup> executable header or an ELKS `a.out` file.

## Sample linker scripts

A script for producing an MS-DOS `MZ` executable, with separate text and data segments, under the old modelling scheme, might look like this:

    /* Run objcopy later to convert the output ELF to "binary" format. */
    OUTPUT_FORMAT ("elf32-i386")
    SECTIONS
    {
      /* MZ file header */
      .msdos_mz_hdr : AT (0)
      {
        /* Magic number. */
        SHORT (0x5a4d)
        …
        /* MZ relocations — the linker is expected to compute these somehow. */
        *(.msdos_mz_reloc .msdos_mz_reloc.*)
        . = ALIGN (16);
        …
      }

      /* Start our first IA-16 segment after the MZ header.  In this scheme,
         it is fine for the actual first byte of a segment to start at a
         non-zero IA-16 offset. */
      .text 0x100 : AT (LOADADDR (.msdos_mz_hdr) + SIZEOF (.msdos_mz_hdr))
      {
        *(.text .text.* .gnu.linkonce.t.*) …
        . = ALIGN (16);
      }

      /* Start a far data segment, at a new IA-16 segment base. */
      .fardata 0 : AT (LOADADDR (.text) + SIZEOF (.text))
      {
        …
        . = ALIGN (16);
      }

      /* Start our "default" data segment. */
      .data 0 : AT (LOADADDR (.fardata) + SIZEOF (.fardata))
      {
        *(.rodata .rodata.* .gnu.linkonce.r.*) …
        *(.data .data.* .gnu.linkonce.d.*) …
      }

      /* .bss will be in the same IA-16 segment as .data. */
      .bss (NOLOAD) :
      {
        *(.bss .bss.* .gnu.linkonce.b.*) …
        *(COMMON) …
        . = ALIGN (16);
      } …

      /* Throw away everything else. */
      /DISCARD/ : { *(*) }
    }

A script for producing a CauseWay DOS extender `3P` executable, with separate text and data segments, under the new `segelf` modelling scheme, might look like this:

    /* Run objcopy later to convert the output ELF to "binary" format. */
    OUTPUT_FORMAT ("elf32-i386")
    SECTIONS
    {
      /* Any needed front matter. */
      …

      /* segelf segment start markers for target text section. */
      ".text!" . (NOLOAD) :
      {
        "__stext!" = .;
        *(".text!*" ".text.*!") …
        "__etext!" = .; …
      }

      /* Target text section. */
      .text . :
      {
        __stext = .;
        *(.text ".text.*[^&]") …
        __etext = .; …
        . = ALIGN (16);
      }

      /* segelf segment end markers for target text section. */
      ".text&" . (NOLOAD) :
      {
        "__stext&" = .;
        *(".text&*" ".text.*&") …
        "__etext&" = .; …
      }

      /* segelf segment start markers for target data section. */
      ".data!" . (NOLOAD) :
      {
        "__sdata!" = .;
        *(".data!*" ".data.*!") …
        "__edata!" = .;
        "__ebss!" = .; …
      }

      /* Target data section. */
      .data . :
      {
        __sdata = .;
        *(.data ".data.*[^&]") …
        __edata = .; …
      }

      /* Target BSS section, with same segment bases as data section. */
      .bss . (NOLOAD) :
      {
        *(.bss ".bss.*[^&]") …
        __ebss = .; …
      }

      /* segelf segment end markers for target data section. */
      ".data&" . (NOLOAD) :
      {
        "__sdata&" = .;
        *(".data&*" ".data.*&") …
        *(".bss&*" ".bss.*&") …
        "__edata&" = .;
        "__ebss& " = .; …
      } …

      /* Throw away everything else. */
      /DISCARD/ : { *(*) }
    }

## Footnotes

<sup>[1] TIS Committee.  _Tool Interface Standard (TIS) Executable and Linking Format (ELF) Specification: Version 1.2_. 1995. [`refspecs.linuxbase.org/elf/elf.pdf`](http://refspecs.linuxbase.org/elf/elf.pdf).</sup>

<sup>[2] Santa Cruz Operation.  _System V Application Binary Interface: Intel386™ Architecture Processor Supplement, Fourth Edition_. 1997. [`www.sco.com/developers/devspecs/abi386-4.pdf`](http://www.sco.com/developers/devspecs/abi386-4.pdf).</sup>

<sup>[3] H. J. Lu et al., ed.  _System V Application Binary Interface: Intel386 Architecture Processor Supplement, Version 1.1_.  2015. [`https://github.com/hjl-tools/x86-psABI/wiki/intel386-psABI-1.1.pdf`](https://github.com/hjl-tools/x86-psABI/wiki/intel386-psABI-1.1.pdf).</sup>

<sup>[4] [`https://github.com/tkchia/binutils-ia16`](https://github.com/tkchia/binutils-ia16).  Partly forked from Jenner's `binutils-ia16` port at [`https://github.com/crtc-demos/binutils-ia16`](https://github.com/crtc-demos/binutils-ia16).</sup>

<sup>[5] [`https://github.com/tkchia/gcc-ia16`](https://github.com/tkchia/binutils-ia16).  Forked from Jenner's `gcc-ia16` port at [`https://github.com/crtc-demos/gcc-ia16`](https://github.com/crtc-demos/gcc-ia16).</sup>

<sup>[6] Intel Corporation.  _iAPX 286 Programmer's Reference Manual_.  1983.</sup>

<sup>[7] [`https://github.com/FDOS/kernel`](https://github.com/FDOS/kernel)

<sup>[8] [`https://github.com/jbruchon/elks`](https://github.com/jbruchon/elks)

<sup>[9] H. P. Anvin.  ABI for 16-bit real mode segmented code in ELF.  2019.  [`https://git.zytor.com/users/hpa/segelf/abi.git/plain/segelf.txt`](https://git.zytor.com/users/hpa/segelf/abi.git/plain/segelf.txt)</sup>

<sup>[10] H. P. Anvin wrote at [`https://bugzilla.nasm.us/show_bug.cgi?id=3392533`](https://bugzilla.nasm.us/show_bug.cgi?id=3392533), "it probably would involve creating a new section (say '`section~`' or '`~group`') that would sort at the _end_ of the relevant segment".  However, I think using `&` rather than `~` as a "sigil" works better — the sigil should sort lexicographically _before_ "normal" symbol characters such as `.`, digits, and letters.

<sup>[11] Intel Corporation.  _Intel® 64 and IA-32 Architectures Software Developer’s Manual_.  _Volume 3B: System Programming Guide, Part 2_.  May 2019.  Chapter 20.</sup>

<sup>[12] See Ralf Brown's Interrupt List ([`www.cs.cmu.edu/afs/cs.cmu.edu/user/ralf/pub/WWW/files.html`](http://www.cs.cmu.edu/afs/cs.cmu.edu/user/ralf/pub/WWW/files.html)) on `int 0x21`, `ah = 0x4b`.
