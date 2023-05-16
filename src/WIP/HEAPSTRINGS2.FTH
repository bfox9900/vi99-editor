\ heapstrings.fth  loads dv80 into heap as strings Sept 2022 Brian Fox
 
\ This version compiles file data as counted strings in low RAM.
\ with words to insert and remove a no. of lines from the buffer 

 NEEDS .S   FROM DSK1.TOOLS 
NEEDS READ-LINE FROM DSK1.ANSFILES
 
HERE
 
\ ===[ heap management ]====
\ low RAM is file TXTBUFFER
HEX
2000 CONSTANT TXTBUFFER  \ base address of the heap
2000 CONSTANT 8K      \ max size of the heap
TXTBUFFER 8K +  CONSTANT BUFFEND
 
DECIMAL
\ variable H is our memory management pointer
 
: HALLOT ( n --)  \ WITH memory protection
  H
  2DUP @ + BUFFEND TXTBUFFER WITHIN ABORT" HEAP error"
  +! ;
 
: HEAP   H @ ;
: HC,   ( c --)  HEAP C!  1 HALLOT ;    \ compile c into heap

: FSIZE    ( -- n )  HEAP TXTBUFFER - ;
: LEN      S" C@" EVALUATE ; IMMEDIATE  \ syntax sugar
  
\ : NEXT$    ( addr -- addr' ) COUNT + ;
HEX
CODE NEXT$ ( addr -- addr' )
     C044 , \   TOS R1 MOV,
     0584 , \      TOS INC,
     D051 , \ R1 ** R1 MOVB,
     0981 , \    R1  8 SRL,
     A101 , \   R1 TOS ADD,
     NEXT,
ENDCODE
 
\ purge sets the heap to use addr and then erases it
: PURGE    ( addr len -- ) 
  OVER H !  0 FILL   
  0 HC,           \ line zer0 must be an empty string   
  LINES OFF  ;
  
: NTH    ( addr n -- Caddr)  0 ?DO NEXT$ LOOP ; \ seek to nth line
: GOTOLN ( ln# -- $) TXTBUFFER SWAP NTH ;
 
DECIMAL
: V$,  ( Vaddr u -- ) \ compile VDP stack string as counted string in HEAP
      1 MAX               \ smallest string we store is 1 byte
      TUCK                \ tuck a copy of length under Vaddr
      DUP HC,             \ compile the length in heap
      HEAP SWAP VREAD     \ copy VRAM to RAM
      HALLOT ;            \ Allocate the heap space
 
: FDATA  ( -- Vaddr len ) [PAB FBUFF] V@  [PAB CHARS] VC@ ;
 
\ usage:  #1  S" DSK1.MYFILE" READ-FILE
: READ-FILE ( addr len -- )
        TXTBUFFER 8K PURGE
        DV80 R/O OPEN-FILE ?FILERR >R
        LINES OFF
        BEGIN
          R@ SELECT 2 FILEOP 0= \ faster than ANS read-line
        WHILE
          FDATA V$,
          LINES 1+!
        REPEAT
        R> CLOSE-FILE DROP
;
 
\ usage:  #1 S" DSK1.MYFILE" WRITE-FILE
: WRITE-FILE ( addr len -- )
        DV80 W/O  OPEN-FILE ?FILERR >R
        TXTBUFFER NEXT$     \ text starts at line 1 
        BEGIN
          DUP LEN
        WHILE
          DUP COUNT R@ WRITE-LINE ?FILERR
          NEXT$
        REPEAT
        DROP
        R> CLOSE-FILE DROP ;
 
: dest$     ( len SRC$ -- len SRC$ DEST$ ) 2DUP + 1+ ; 
: length    ( len SRC$ DEST$ --  len SRC$ DEST$ n) 2DUP SWAP - ; 
: openafter ( len $addr -- $addr) 
  DUP>R  dest$ length  
  DUP HALLOT  
  FSIZE SWAP - MOVE R> ;
  
: INSERT-ABOVE ( addr len line# --) GOTOLN openafter PLACE ;  
: INSERT-BELOW ( addr len line# --) 1+ INSERT-ABOVE ;
: REPLACE$  ;

: COPY-LINES ( n line# --) \ copy to VDP paste buffer 
  GOTOLN  DUP ROT NTH  ( addr1 addr2 ) OVER - VP @ SWAP VWRITE ; 

: removal ( n line#  -- #bytes) 
\ remove n lines from HEAP of strings @ line#
  GOTOLN  
  DUP ROT NTH 
  TUCK OVER - FSIZE 1- SWAP - DUP>R MOVE 
  R> ;  

: deallot ( n -- )
  HEAP 1- OVER -   8  0 FILL         \ mark end of text with zeros  
  HEAP SWAP - TXTBUFFER MAX H ! ;  \ deallocate

: REMOVE-LINES  ( n line# -- ) OVER 2 < ABORT" < 2 lines"  removal deallot ;

DECIMAL HERE SWAP - CR . .( bytes)

\ TEST CODE ....................................................
: LOAD    S" DSK1.BUFFER" READ-FILE ;
: PRINT  ( $ -- ) 
  COUNT ( C/L@ 1- MIN)  CR TYPE 
;

: .HEAP ( n -- )
  GOTOLN  
  BEGIN DUP LEN 
  WHILE   
    DUP PRINT 
    ?TERMINAL ABORT" stopped"
    NEXT$ 
  REPEAT 
  DROP ;
: LIST   PAGE 1 .HEAP ;

 : A$   S" Now is the time for all good men!" ;

\ non-ascii detection: make all non-ascii chars a block character
INCLUDE DSK1.LOADSAVE 
HEX 
: FILL-FONT  800 1000 FF VFILL ;
: DETECTOR    FILL-FONT   S" DSK1.FONT0230"  LOAD-FONT ;
DECIMAL 





