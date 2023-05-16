\ ls-l  ( CAT )
NEEDS PARSE-DEV FROM DSK4.VILS 
NEEDS U.R       FROM DSK1.UDOTR
 
 : $.       ( $addr -- ) COUNT TYPE ;
 : $.LEFT   ( $ width -- ) OVER C@ - >R $.  R> SPACES ;
 : FIELD++  ( addr len -- addr' len') + COUNT ;
 
\ 4 DIGIT BCD to int convertor. Limited to 9999 (Lee's correction)
HEX
: F>INT   ( addr len -- addr len n)
          OVER C@  ( -- mantissa)
          CASE
            0 OF  0                    ENDOF
           40 OF  OVER 1+ C@           ENDOF
           41 OF  OVER 1+ C@ 64 * >R
                  OVER 2+ C@  R> +     ENDOF
           ( default)
                  SWAP -1  \ bad # indicator
           ENDCASE ;
 
DECIMAL
: HEAD.REC ( addr -- )
          CR  
          DECIMAL
          DUP 7 $.LEFT SPACE COUNT ( addr len)
          FIELD++
          ."  Size " FIELD++ F>INT 5 U.R   ."  Used " FIELD++ F>INT 5 U.R
          2DROP ;
 
: DIR.TYPE  ( addr -- )
          F>INT
          CASE
             1 OF ." Txt/Fix"  ENDOF
             2 OF ." Txt/Var"  ENDOF
             3 OF ." Bin/Fix"  ENDOF
             4 OF ." Bin/Var"  ENDOF
             5 OF ." Program"  ENDOF
             ." ????"
          ENDCASE ;
 
: DIR.REC ( addr -- )
          CR 
          DUP  11 $.LEFT SPACE COUNT ( addr len)
          FIELD++ DIR.TYPE
          FIELD++ F>INT 7 U.R
          FIELD++ F>INT 7 U.R
          2DROP ;
 
: ls-l  ( path )
          BASE @ >R DECIMAL
          PARSE-DEV OPEN-CATFILE >R  \ store file handle
 
          PAD DUP 80 R@ READH  HEAD.REC
          CR 13 SPACES  ." -type-  -sect- -b/rec-"
 
          LINES OFF
          BEGIN
             PAD DUP 80 R@ READH C@   \ do while length > 0
          WHILE
            ^C? 0=
          WHILE
             PAD DIR.REC
             LINES 1+!
             SPACEBAR
          REPEAT
          CR ." ^C"
          THEN
          R> CLOSE
          CR LINES @ . ." files" CR
          R> BASE ! ;
 
