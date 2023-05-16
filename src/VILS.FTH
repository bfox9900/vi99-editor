\ VILS.FTH  read a TI disk directory for VI99 Oct 4 2022
\ provides support for ls-l
 
NEEDS OPEN-FILE FROM DSK1.ANSFILES
NEEDS VALUE FROM DSK1.VALUES
 
HEX
: GETKEY?   RKEY? 7F AND ;
: SPACEBAR ( -- c ) RKEY? BL = IF 100 MS RKEY DROP THEN ;
 
0 VALUE #1   0 VALUE #2   0 VALUE #3
 
: OPEN  ( addr len -- hndl ) OPEN-FILE ?FILERR ;
: CLOSE ( hndl -- )         CLOSE-FILE ?FILERR ;
: READH ( hndl -- )         READ-LINE ?FILERR 2DROP ;
 
DECIMAL
: ?CR   ( n -- ) VCOL @  C/L@ 12 - > IF CR THEN ;
: ^C?   ( -- ?)  GETKEY? ^ C =  ;
: LTYPE ( addr len width -- ) OVER - >R TYPE R> SPACES ;
 
: OPEN-CATFILE ( adr len -- hndl) RELATIVE 256 FIXED R/O BIN OPEN ;
 
: PARSE-DEV ( -- addr len)
  PARSE-NAME TOUPPER DUP 0=     \ test length
  IF  2DROP $HOME COUNT  THEN ; \ replace with default dev$
 
: ls  ( <DSK?.> )   \  needs the '.' ONLY shows file name
  PARSE-DEV OPEN-CATFILE >R  \ push handle onto Return stack
  PAD 80 R@ READH
  CR PAD COUNT TYPE
  CR
  0    \ accumulator
  BEGIN
    PAD DUP 80 R@ READH C@
  WHILE \ do while length > 0
    ^C? 0=
  WHILE
    PAD COUNT 12 LTYPE ?CR
    1+    \ bump file count
    SPACEBAR
  REPEAT
  CR ." ^C"
  THEN
  R> CLOSE-FILE ?FILERR
  DECIMAL
  CR DUP . ." files" CR
;
 
