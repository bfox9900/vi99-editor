\ vdp-string-stack.fth       2023  Brian Fox 
\ Problem: create a stack structure of end-to-end counted strings

\ This system creates a stack of pointers in high VDP RAM growing down.
\ The stack pointers point to byte-counted strings that grow upwards.

\ VDP Memory Usage in Camel99 Forth when this file is loaded
\ |  VDP screen   |  VDP >0000 >078F (80 column mode)
\ + --------------|
\ |   RESERVED    |    sprites, patterns color tables
\ |---------------|
\ |  >460..7FF    |  *FREE 928 bytes in TEXT mode only*
\ |---------------|
\ |  >800..       |  *Pattern descriptor table*
\ +---------------+  HEX 1000, VDP HEAP start
\ |compact strings|  moves upwards
\ |     8K        |
\ |      .        |
\ |      .        |
\ |      .        |
\ |      .        |
\ |      .        |
\ |      .        |
\ |      .        |
\ | ^^^^^^^^^^^   |
\ | pointer stack |
\ |---------------| 
\ |   ^^^^^^^     |  move downwards
\ |  PAB stack    |  PABs start here
\ +---------------+ <-- VDPTOP returns this address
\ | 99 O/S space  |
\ |---------------| VDP >3FFF

\ NEEDS DUMP  FROM DSK1.TOOLS 
NEEDS VHERE FROM DSK1.VDPMEM 

HEX 
VDPTOP 390 - CONSTANT VSTACK    \ vdp integer stack base address 
VARIABLE VSP                    \ Stack pointer for VDP stack  

\ integer stack in VDP RAM
: ?VSTACK   VSP @ VSTACK > ABORT" VDP stack underflow" ;
: >VSTK  ( n -- ) -2 VSP +!   VSP @ V! ;
: VSTK@  ( -- n)  VSP @  V@ ;
: VSTK>  ( -- n)  VSTK@  2 VSP +! ?VSTACK ;

\ compile CPU string into VDP memory, return the address 
: V$,   ( addr len -- Vaddr) VHERE DUP>R  OVER 1+ VALLOT  VPLACE  R> ;

: V$@ ( Vaddr len addr -- )  2DUP C! 1+ SWAP VREAD ;

\ -----------------------------------------------------------------
\ API 
: V$PUSH ( addr len ) V$, >VSTK ;

: V$POP  ( --  addr len ) 
    VSTK> VCOUNT PAD V$@        \ read the string to PAD 
    PAD COUNT                   \ convert to addr,len 
    DUP 1+ NEGATE VALLOT  ;     \ de-allocated the string 
                                \ & count byte from VDP memory 

HEX 
: INIT-VSTACK   VSTACK VSP !   1000 VP ! ;

INIT-VSTACK 

