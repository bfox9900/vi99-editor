\ VPDHEAPSTRING.fth  loads dv80 into vdpram as strings Nov 2023 Brian Fox
\ there is more space in VDP for the file than in Low RAM. 
 
\ *experimental* 

HERE
 
\ ===[ heap management ]====
\ low RAM is file TXTBUFFER
HEX
2000 CONSTANT TXTBUFFER  \ base address of the heap
2000 CONSTANT 8K         \ max size of the heap
TXTBUFFER 8K +  CONSTANT BUFFEND
 
\ READ-FILE to VDP RAM as counted strings    Fox 2022
\ It's your job to move the data where you want it :-)

NEEDS .S        FROM DSK1.TOOLS
NEEDS ELAPSE    FROM DSK1.ELAPSE
NEEDS READ-LINE FROM DSK1.ANSFILES
NEEDS MALLOC    FROM DSK1.MALLOC
NEEDS VHERE     FROM DSK1.VDPMEM
NEEDS VTYPE     FROM DSK1.VTYPE

HEX
  0D CONSTANT ^M         \ carriage return
  1A CONSTANT ^Z         \ end of Text file marker

1000 CONSTANT VDPBUFF    \ Free VDP ram after pattern table
2600 CONSTANT MEM-SIZE   \ 9728 bytes is largest file

     VARIABLE #LINES     \ no. of lines in file
     VARIABLE #BYTES     \ no. of bytes in file (with delimiters)

HEX

: NEXT$  ( V$ -- V$') VCOUNT + ;

: NTH  ( n --)  0 ?DO  NEXT$ LOOP ;

: PURGE-VRAM  ( -- )
  VDPBUFF VP !
  VHERE MEM-SIZE 0 VFILL ;  \ erase VRAM

: READF ( -- Vaddr len ior)  
      VHERE                   \ get next available address 
      0 VC,                   \ compile the count byte 
      VHERE [PAB FBUFF] V!    \ set the file buffer to VHERE 
      2 FILEOP                \ do a file read 
      [PAB CHARS] VC@         \ get the #chars read 
      DUP VALLOT              \ allocate vdp space
      SWAP  ;                 \ put ior on top  

: READ-FILE  ( $addr len -- ior)
      PURGE-VRAM
      #LINES OFF
      #BYTES OFF
      R/O OPEN-FILE ?FILERR >R
      BEGIN
         READF ( -- Vaddr len ior)  
      0= WHILE
        SWAP VC!               \ update the string length
        #LINES 1+!
      REPEAT
      2DROP
      0 VC,                    \ compile 0 byte
      R> CLOSE-FILE
;

: VDPTYPE ( Vaddr len -- V$)  BOUNDS ?DO  I VC@ EMIT LOOP ;

: .V$  ( $Vaddr -- ) VCOUNT VDPTYPE ;

DECIMAL
: LISTALL 
    VDPBUFF
    BEGIN 
      DUP VC@   \ test length 
    WHILE          
      DUP  CR .V$ 
      NEXT$
      ?TERMINAL ABORT" HALT" 
    REPEAT     
;

