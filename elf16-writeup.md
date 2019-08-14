# New ELF i386 relocation types to support 16-bit x86 segmented addressing

(TK Chia — 15 Aug 2019 version)

The new ELF i386<sup>[1][2][3]</sup> relocations described below have been implemented in the main branch of my fork of GNU Binutils,<sup>[4]</sup> and are also partially supported by my fork of GCC.<sup>[5]</sup>  They allow one to use ELF i386 as an intermediate object format, to support the linking of 16-bit x86<sup>[6]</sup> programs whose code and data may span multiple segments.

The `R_386_OZSEG16` relocation (a.k.a. `R_386_SEGMENT16`) is stable enough and already used in existing code.  The rest of the ABI is evolving and subject to change.

## Discussion: modelling IA-16 segments in GNU Binutils

In IA-16 segmented code, program memory is grouped into _segments_, each segment being a contiguous slice of the system's flat address space.  Each memory item is addressed as an _offset_ into a segment which contains it: thus, a Segment(_S_)`:`Offset(_S_) pair.  There are at least two general ways to model Segment`:`Offset addressing under ELF.

### Default (LMA ≠ VMA) relocation scheme

Binutils's binary file descriptor (BFD) engine allows each output segment to have both a _virtual address_ (VMA) and a _load address_ (LMA).  This gives rise to a simplistic way to represent separate IA-16 segments: as output segments in BFD with distinct LMAs but overlapping VMAs (corresponding to in-segment offsets).

An instruction and relocation sequence to load a far pointer to a variable `foo` in `%dx:%ax` might look like this:

       0:	b8 00 00             	mov    $0x0,%ax
    			1: R_386_16	foo
       3:	ba 00 00             	mov    $0x0,%dx
    			4: R_386_OZSEG16	foo

### New `segelf` relocation scheme

H. Peter Anvin has proposed a different Segment`:`Offset modelling scheme<sup>[7]</sup> (_q. v._ for more information).  This scheme relies only on VMAs.  In this scheme, for each symbol _S_, there should be a matching symbol _S_`!` giving the VMA of _S_'s IA-16 segment base.

An instruction and relocation sequence to load a far pointer to a variable `foo` in `%dx:%ax` might look like this:

       0:	b8 00 00             	mov    $0x0,%ax
    			1: R_386_16	foo
    			1: R_386_SUB16	foo!
       3:	ba 00 00             	mov    $0x0,%dx
    			4: R_386_SEG16	foo!
			
This scheme is supported by my Binutils fork — in particular, you can enable it in the Binutils assembler with the option `--32-segelf`.

The `segelf` scheme can also be enabled in (my forked) GCC, through a `-msegelf` option.  However, the platform libraries and `libgcc` have not been set up to use this scheme, so you may need to recompile them.

## The new relocation types

Relocation type name   | Value | Field  | Calculation                                 | Remarks
---------------------- | :---: | :----: | ------------------------------------------- | :------
`R_386_SEG16`          |   45  | word16 | _M_((_A_ `<<` 4) + _S_ + _B_)<sup>[8]</sup> | Used by Anvin's `segelf` scheme
`R_386_SUB16`          |   46  | word16 | _A_ - _S_                                   | Used by Anvin's `segelf` scheme
`R_386_SUB32`          |   47  | word32 | _A_ - _S_                                   | Used by Anvin's `segelf` scheme
`R_386_SEGRELATIVE`    |   48  | word16 | _M_((_A_ `<<` 4) + _B_)                     | Used by Anvin's `segelf` scheme
`R_386_OZSEG16`        |   80  | word16 | _A_ + _M_(_Z_(_S_) + _B_)                   | Used by the LMA ≠ VMA scheme
`R_386_OZRELSEG16`     |   81  | word16 | _A_ + (_Z_(_S_) `>>` 4)                     | Used by the LMA ≠ VMA scheme

Definitions:

  * _A_, _S_: the addend and symbol value for the relocation, per the original ELF specification.<sup>[1]</sup>
  * _B_: the notional flat address — known only at program run time — where the first byte of the program will be loaded.
  * _H_: the LMA or VMA in the program image which will end up at address _B_ at runtime.  (This is a bit of a hack, to allow linker scripts to synthesize non-ELF file format headers at link time.)  _H_ is computed as
    * the LMA of the end of a section named `.msdos_mz_hdr`, if any;
    * or zero.
  * _Z_(_S_): an address for "IA-16 offset 0" in _S_'s output section _X_.  This is computed as the LMA corresponding to VMA 0 of _X_, minus _H_.
  * _M_(·): a function to map a segment base address to a segment register value.  For a program which will run in x86 real mode,<sup>[9]</sup> this will simply shift the address right by 4 bits.

An `R_386_OZSEG16` or `R_386_SEG16` corresponds to a segment relocation in an MS-DOS `MZ`<sup>[10]</sup> executable header.  The linker will only try to synthesize `MZ` relocations from ELF relocations if there will be an `.msdos_mz_hdr` section in the output program.  I hope to generalize the synthesizing of relocations to other executable formats.

Currently, programs that only use the `R_386_OZSEG16` and `R_386_OZRELSEG16` relocations may be linked directly as `binary` format files.

## Sample linker script

A script for producing an MS-DOS `MZ` executable with separate text and data segments under the old modelling scheme might look like this:

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
        /* MZ relocations — the linker is expected to compute these. */
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

## Footnotes

<sup>[1] TIS Committee.  _Tool Interface Standard (TIS) Executable and Linking Format (ELF) Specification: Version 1.2_. 1995. [`refspecs.linuxbase.org/elf/elf.pdf`](http://refspecs.linuxbase.org/elf/elf.pdf).</sup>

<sup>[2] Santa Cruz Operation.  _System V Application Binary Interface: Intel386™ Architecture Processor Supplement, Fourth Edition_. 1997. [`www.sco.com/developers/devspecs/abi386-4.pdf`](http://www.sco.com/developers/devspecs/abi386-4.pdf).</sup>

<sup>[3] H. J. Lu et al., ed.  _System V Application Binary Interface: Intel386 Architecture Processor Supplement, Version 1.1_.  2015. [`https://github.com/hjl-tools/x86-psABI/wiki/intel386-psABI-1.1.pdf`](https://github.com/hjl-tools/x86-psABI/wiki/intel386-psABI-1.1.pdf).</sup>

<sup>[4] [`https://github.com/tkchia/binutils-ia16`](https://github.com/tkchia/binutils-ia16).  Partly forked from Jenner's `binutils-ia16` port at [`https://github.com/crtc-demos/binutils-ia16`](https://github.com/crtc-demos/binutils-ia16).</sup>

<sup>[5] [`https://github.com/tkchia/gcc-ia16`](https://github.com/tkchia/binutils-ia16).  Forked from Jenner's `gcc-ia16` port at [`https://github.com/crtc-demos/gcc-ia16`](https://github.com/crtc-demos/gcc-ia16).</sup>

<sup>[6] Intel Corporation.  _iAPX 286 Programmer's Reference Manual_.  1983.</sup>

<sup>[7] H. P. Anvin.  ABI for 16-bit real mode segmented code in ELF.  2019.  [`https://git.zytor.com/users/hpa/segelf/abi.git/plain/segelf.txt`](https://git.zytor.com/users/hpa/segelf/abi.git/plain/segelf.txt)</sup>

<sup>[8] The ABI document says _A_ + (_S_ `>>` 4), i.e. _M_((_A_ `<<` 4) + _S_), but I believe this is incorrect.</sup>

<sup>[9] Intel Corporation.  _Intel® 64 and IA-32 Architectures Software Developer’s Manual_.  _Volume 3B: System Programming Guide, Part 2_.  May 2019.  Chapter 20.</sup>

<sup>[10] See Ralf Brown's Interrupt List ([`www.cs.cmu.edu/afs/cs.cmu.edu/user/ralf/pub/WWW/files.html`](http://www.cs.cmu.edu/afs/cs.cmu.edu/user/ralf/pub/WWW/files.html)) on `int 0x21`, `ah = 0x4b`.
