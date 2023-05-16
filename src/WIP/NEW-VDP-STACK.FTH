\ This string stack uses an integer stack of pointers 
\ that point to count strings. Everything resides in VDP RAM 

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

\ get VDP string into CPU RAM as a counted string 
: V$PLACE ( Vaddr len addr -- )  2DUP C! 1+ SWAP VREAD ;

\ -----------------------------------------------------------------
\ API 
: LDEPTH    ( -- n) VSTACK VSP @ - 2/ ;
: STKFULL?  ( -- ?) LDEPTH 250 >   ;

: V$PUSH ( addr len ) V$, >VSTK ;

: V$POP  ( --  addr len ) 
    VSTK> VCOUNT PAD V$PLACE     \ read the string to PAD 
    PAD COUNT                   \ convert to addr,len 
    DUP 1+ NEGATE VALLOT  ;     \ de-allocated the string & count byte from VDP memory 

HEX 
: INIT-VSTACK   VSTACK VSP !   1000 VP ! ;

INIT-VSTACK 
