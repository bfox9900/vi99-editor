\ VDPline stack for cut/paste 

NEEDS VHERE      FROM DSK1.VDPMEM

HEX 
200 CONSTANT VSTKSIZE ( 200*2=400 bytes )

\ leave room for 3 PABs (PSZ is pab size) 
VDPTOP PSZ 3 * - CONSTANT VSTACK  

\ integer stack in VDP RAM
VARIABLE VSP                  \ Stack pointer for VDP stack  
: ?VSTACK   VSP @ VSTACK > ABORT" VDP stack underflow" ;
: >VSTK  ( n -- ) -2 VSP +!   VSP @ V! ;
: VSTK@  ( -- VAddr)  VSP @  V@ ;
: VSTK>  ( -- Vaddr)  VSTK@  2 VSP +! ?VSTACK ;

\ compile CPU string into VDP memory, return the address 
: V$,   ( addr len -- Vaddr) VHERE DUP>R  OVER 1+ VALLOT  VPLACE  R> ;

\ -----------------------------------------------------------------
\                 VDP string stack API 
: LDEPTH    ( -- n) VSTACK VSP @ - 2/ ;
: ?VSTKFULL  ( -- ?) LDEPTH VSTKSIZE > ABORT" VDP stack overflow" ;

: V$PUSH ( addr len ) ?VSTKFULL  V$, >VSTK ;

: V$POP  ( --  addr len ) 
  VSTK> VCOUNT PAD V$PLACE  \ read the string to PAD 
  PAD COUNT                 \ convert to addr,len 
  DUP 1+ NEGATE VALLOT  ;   \ de-allocated the string & count byte

HEX 
:  KILL-BUFFER   VSTACK VSP !   C00 VP ! ;

KILL-BUFFER   \ inits the VSTACK 

  DECIMAL
: PUSHLN ( line# -- ) GOTOLN COUNT V$PUSH ;
