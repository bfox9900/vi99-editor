\ copy text file to text file 

NEEDS OPEN-FILE  FROM DSK1.ANSFILES
NEEDS VALUE      FROM DSK1.VALUES

HEX
0 VALUE #out  \ these hold the file handles
0 VALUE #in
0 VALUE INPATH
0 VALUE OUTPATH 

CREATE #BYTES 0 , 0 , \ 32 bit byte counter for big files
: #BYTES+! ( n -- ) #BYTES 2@ ROT M+ #BYTES 2! ; \ add n, 32bit sum


\ RESERVE/RESTORE: cheap way to allocate dictionary space and return it
: RESERVE  ( n -- addr) HERE ALLOT ;
: RESTORE  ( n -- ) NEGATE ALLOT ;

: FNAME  ( -- addr len ) 
         PARSE-NAME +PATH ;

: FILE.REPORT
  BASE @ >R
  DECIMAL
  CR LINES @ . ." lines, " #BYTES 2@ UD. ." bytes"
  R> BASE ! ;

DECIMAL 
DECIMAL
: MOVE-FILE ( buff-size -- buff-size)
        0 0 #BYTES 2!
        DUP RESERVE >R
        LINES OFF
        SPACE
        BEGIN
          R@  BUFFSIZE #in READ-LINE ?FILERR ( -- #bytes eof?) DROP
          DUP #BYTES+!
          R@ SWAP #out WRITE-LINE ?FILERR
          LINES 1+!
          #in EOF
        UNTIL
        R> DROP  \ DROP buffer address from rstack
        RESTORE 
;
: OPENF  OPEN-FILE  ?FILERR ;
: CLOSEF CLOSE-FILE ?FILERR ;

DECIMAL
: cp ( <file1> <file2> )
        ?FAM
        FNAME FNAME 
        SURE?
        0= IF  2DROP 2DROP  .CANCEL EXIT THEN 
        W/O OPENF TO #out
        R/O OPENF TO #in
        128 MOVE-FILE
        #out CLOSEF 
        #in  CLOSEF 
        CR ." Copy complete. "
        FILE.REPORT
;

: cat  ( <file1> <file2> )
        PATH$ ARG$
        W/A  OPENF TO #2  \ *new* W/A, open destination in Append mode
        R/O  OPENF TO #1
        BUFFSIZE MOVE-FILE
        #2 CLOSEF
        #1 CLOSEF
        CR ." Append complete"
        FILE.REPORT
;
