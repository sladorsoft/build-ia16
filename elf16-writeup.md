# Proposed ELF i386 relocations and section types to support 16-bit x86 segmented addressing

(TK Chia — 28 July 2019 version)

The new ELF i386<sup>[1][2][3]</sup> relocations and new ELF section types described below have been implemented in the main branch of my fork of GNU Binutils<sup>[4]</sup>, and are used by my fork of the Netwide Assembler.<sup>[5]</sup>  They allow one to use ELF i386 as an intermediate object format, to support the linking of 16-bit x86<sup>[6]</sup> programs whose code and data may span multiple segments.

The `R_386_SEGMENT16` relocation is stable enough and already used in existing code.  The rest of the ABI is evolving and subject to change.

## Discussion: modelling IA-16 segments in GNU Binutils

In IA-16 segmented code, program memory is grouped into _segments_, each segment being a contiguous slice of the system's flat address space.  Each memory item is addressed as an _offset_ into a segment which contains it: thus, a Segment(_S_)`:`Offset(_S_) pair.  There are at least two general ways to model Segment`:`Offset addressing under ELF.

### Old default relocation scheme

Binutils's binary file descriptor (BFD) engine allows each output segment to have both a _virtual address_ (VMA) and a _load address_ (LMA).  This gives rise to a simplistic way to represent separate IA-16 segments: as output segments in BFD with distinct LMAs but overlapping VMAs (corresponding to in-segment offsets).

An instruction and relocation sequence to load a far pointer to a variable `foo` in `%dx:%ax` might look like this:

       0:	b8 00 00             	mov    $0x0,%ax
    			1: R_386_16	foo
       3:	ba 00 00             	mov    $0x0,%dx
    			4: R_386_SEGMENT16	foo

### Alternative relocation scheme

H. Peter Anvin has outlined<sup>[7]</sup> a different Segment`:`Offset modelling scheme.  Here VMAs and LMAs provide the same flat-address view of the whole program (as in the original ELF i386).  This means extra relocations are needed to extract the in-segment offset of each symbol _S_, but it means we avoid overloading BFD's LMA ≠ VMA mechanism for an unintended use.

This scheme is implemented in my fork of the GNU linker, but not yet in the GNU assembler.

An instruction and relocation sequence to load a far pointer to `foo` in `%dx:%ax` might look like this:

       0:	b8 00 00             	mov    $0x0,%ax
    			1: R_386_16	foo
    			1: R_386_OZSUB16	foo
       3:	ba 00 00             	mov    $0x0,%dx
    			4: R_386_SEGMENT16	foo

## The new relocation types and section types

Relocation type name   | Value | Field  | Calculation
---------------------- | :---: | :----: | -----------
`R_386_SEGMENT16`      |   80  | word16 | _A_ + _M_(_Z_(_S_) + _B_)
`R_386_RELSEG16`       |   81  | word16 | _A_ + (_Z_(_S_) `>>` 4)
`R_386_OZSUB16`        |   82  | word16 | _A_ - _Z_(_S_)
`R_386_OZSUB32`        |   83  | word32 | _A_ - _Z_(_S_)
`R_386_OZ16`           |   84  | word16 | _A_ + _Z_(_S_)
`R_386_OZ32`           |   85  | word32 | _A_ + _Z_(_S_)

Section type name         | Value        | Remarks
------------------------- | :----------: | -------
`SHT_IA16_PROG_ORG`       | `0x8086006f` | Marks origin point of program in old relocation scheme
`SHT_IA16_PROG_ORG_VADDR` | `0x8086016f` | Marks origin point of program in alternative relocation scheme
`SHT_IA16_SEC_OZ_VADDR`   | `0x8086017a` | Marks IA-16 base for another section (via `sh_link`) in alternative relocation scheme

Definitions:

  * _A_, _S_: the addend and symbol value for the relocation, per the original ELF specification.<sup>[1]</sup>
  * _B_: the notional flat address — known only at program run time — where the first byte of the program will be loaded.
  * _H_: the LMA or VMA in the program image which will end up at address _B_ at runtime.  (This is a bit of a hack, to allow linker scripts to synthesize non-ELF file format headers at link time.)  _H_ is computed as
    * the VMA just after an `SHT_IA16_PROG_ORG_VADDR` section, if any;
    * or failing that, the LMA just after an `SHT_IA16_PROG_ORG` section, if any;
    * or, the LMA of the end of a section named `.ia16.hdr`, `.msdos_mz_hdr`, or `.hdr`, if any;
    * or zero.
  * _Z_(_S_): an address for "IA-16 offset 0" in _S_'s output section _X_.  This is computed as
    * the VMA of _X_ minus _H_, if _X_ is itself a `SHT_IA16_SEC_OZ_VADDR` section;
    * or, the VMA of an `SHT_IA16_SEC_OZ_VADDR` section which has an `sh_link` to _X_,<sup>[9]</sup> if any, minus _H_;
    * or, the LMA corresponding to VMA 0 of _X_, minus _H_.
  * _M_(·): a function to map a segment base address to a segment register value.  For a program which will run in x86 real mode,<sup>[8]</sup> this will simply shift the address right by 4 bits.

`R_386_SEGMENT16` corresponds to a segment relocation in an MS-DOS `MZ` executable header;<sup>[10]</sup> I hope to generalize it to segment relocations in other executable formats.  The `R_386_OZ`… relocations are intended to implement the Netwide Assembler's `wrt` operator.

Currently, programs that only use the `R_386_SEGMENT16` and `R_386_RELSEG16` relocations, and no special section types, may be linked directly as `binary` format files.  Programs that use the other relocations or section types must be linked as ELF files first, and then converted (e.g. via `objcopy`) to a non-ELF format.

## Sample linker script

A script for producing an MS-DOS `MZ` executable with separate text and data segments under the old modelling scheme might look like this:

    /* Run objcopy later to convert the output ELF to "binary" format. */
    OUTPUT_FORMAT ("elf32-i386")
    SECTIONS
    {
      /* MZ file header */
      .hdr : AT (0)
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
      .text 0x100 : AT (LOADADDR (.ia16.prog_org))
      {
        *(.text .text.* .gnu.linkonce.t.*) …
        . = ALIGN (16);
      }

      /* Start another new IA-16 segment. */
      .data 0 : AT (LOADADDR (.text) + SIZEOF (.text))
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

      /* A far data segment. */
      .fardata 0 : AT (LOADADDR (.bss) + SIZEOF (.bss))
      {
        …
      }

      /* Throw away everything else. */
      /DISCARD/ : { *(*) }
    }

## Footnotes

<sup>[1] TIS Committee.  _Tool Interface Standard (TIS) Executable and Linking Format (ELF) Specification: Version 1.2_. 1995. [`refspecs.linuxbase.org/elf/elf.pdf`](http://refspecs.linuxbase.org/elf/elf.pdf).</sup>

<sup>[2] Santa Cruz Operation.  _System V Application Binary Interface: Intel386™ Architecture Processor Supplement, Fourth Edition_. 1997. [`www.sco.com/developers/devspecs/abi386-4.pdf`](http://www.sco.com/developers/devspecs/abi386-4.pdf).</sup>

<sup>[3] H. J. Lu et al., ed.  _System V Application Binary Interface: Intel386 Architecture Processor Supplement, Version 1.1_.  2015. [`https://github.com/hjl-tools/x86-psABI/wiki/intel386-psABI-1.1.pdf`](https://github.com/hjl-tools/x86-psABI/wiki/intel386-psABI-1.1.pdf).</sup>

<sup>[4] [`https://github.com/tkchia/binutils-ia16`](https://github.com/tkchia/binutils-ia16).  Partly forked from Jenner's `binutils-ia16` port at [`https://github.com/crtc-demos/binutils-ia16`](https://github.com/crtc-demos/binutils-ia16).</sup>

<sup>[5] [`https://github.com/tkchia/nasm-elf16-oldseg`](https://github.com/tkchia/nasm-elf16-oldseg).

<sup>[6] Intel Corporation.  _iAPX 286 Programmer's Reference Manual_.  1983.</sup>

<sup>[7] [`https://bugzilla.nasm.us/show_bug.cgi?id=3392533#c17`](https://bugzilla.nasm.us/show_bug.cgi?id=3392533#c17).</sup>

<sup>[8] Intel Corporation.  _Intel® 64 and IA-32 Architectures Software Developer’s Manual_.  _Volume 3B: System Programming Guide, Part 2_.  May 2019.  Chapter 20.</sup>

<sup>[9] As a special hack, if a `SHT_IA16_SEC_OZ_ADDR` section named `.data!` has a null `sh_link`, the linker will look for a section named `.data$` or `.data` to associate with it.

<sup>[10] See Ralf Brown's Interrupt List ([`www.cs.cmu.edu/afs/cs.cmu.edu/user/ralf/pub/WWW/files.html`](http://www.cs.cmu.edu/afs/cs.cmu.edu/user/ralf/pub/WWW/files.html)) on `int 0x21`, `ah = 0x4b`.
