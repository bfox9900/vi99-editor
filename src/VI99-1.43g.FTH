\ VI99.FTH  editor for TI-99 V 1.43h    Apr 2, 2023 

\ ** requires F18A 80 column video card **
\ Rebuilt with new RKEY lib that disables interrupts

\ Sept 7, 2022 Brian Fox
\ VI99 concepts:
\ Use VI key mappings.
\ Use Forth interpreter
\ Commands created from key value and interpreted by Forth
\ Read files as byte-counted strings into low ram. (8K max)
\ Edit text directly in VDP RAM (TI-99 screen)

\ *topline now limited to 1 minimum. NOT zero


NEEDS WORDLIST   FROM DSK1.WORDLISTS
ONLY FORTH DEFINITIONS
NEEDS DUMP       FROM DSK1.TOOLS
NEEDS READ-LINE  FROM DSK1.ANSFILES
NEEDS #1         FROM DSK4.HEAPSTRING
NEEDS COMPARE    FROM DSK1.COMPARE 
NEEDS CASE       FROM DSK1.CASE
NEEDS RKEY       FROM DSK1.RKEY
NEEDS -TRAILING  FROM DSK1.TRAILING
\ NEEDS MOVE       FROM DSK1.MOVE
NEEDS MARKER     FROM DSK1.MARKER
NEEDS 80COLS     FROM DSK1.80COL
NEEDS VHERE      FROM DSK1.VDPMEM

MARKER /VI99

HERE

HEX
: ^ ( c -- ) \ compile ctrl char
  ?COMP  CHAR  1F AND
  POSTPONE LITERAL ; IMMEDIATE

DECIMAL
VARIABLE INSERTING
VARIABLE MODE
VARIABLE LINESTK
VARIABLE TOPLINE
VARIABLE LINE#   \ active line#
VARIABLE 'ELINE  \ address of cursor line# in HEAP
VARIABLE  READONLY

C/L@ 1- CONSTANT SCRWIDTH

\ ========================
\ Helpers
: CLIP     ( n lo hi -- n) ROT MIN MAX ;
: ERASE    ( addr len -- )  0 FILL ;
: BLANK    ( addr len -- )  BL FILL ;
: VBLANK   ( vaddr len -- ) BL VFILL ;
: VBLANKLN ( -- ) VPOS C/L@ VBLANK ;  

: HLINE    ( col row -- ) >VPOS C/L@  [CHAR] __ VFILL ;
: .$       ( $ --) COUNT TYPE ;
: BETWEEN  ( n lo hi -- ?) 1+ WITHIN ;


\ V-trailing removes trailing blanks, for a VDP string
: V-TRAILING ( V$ len -- V$ len')
  1-
  BEGIN
     2DUP + VC@ BL =
  WHILE
     1-
  REPEAT
  1+ ;

HEX
\ vdp screen is the editing buffer so we can use the cursor VDP address
: GCHAR  ( -- c ) VPOS VC@ ; 

: GETKEY ( -- c) RKEY 007F AND ; \ c is 7 bit ascii 
\ use for 2nd key stroke in commands like: yy dd dw 
: WAITKEY     GCHAR >R  KEY 007F AND   R> VPUT ; 

\ handy macro
: END     POSTPONE EXIT  POSTPONE THEN ; IMMEDIATE

\ RESERVE/RESTORE: cheap way to allocate dictionary space and return it
\ : RESERVE  ( n -- addr) HERE ALLOT ;
\ : RESTORE  ( n -- ) NEGATE ALLOT ;

\ letter case controls
HEX
: LOWER? ( c -- c') [CHAR] a  [CHAR] z  BETWEEN ;

: TOUPPER ( addr len -- addr len)
  2DUP BOUNDS
  ?DO
    I C@ DUP LOWER?
    IF 05F AND THEN I C!
  LOOP ;

DECIMAL
: DECR    ( addr -- ) DUP @ 1- 0 MAX  SWAP ! ;
: GETXY   ( -- x y )  VROW 2@ ;
: SAVE-XY  S" GETXY 2>R" EVALUATE ; IMMEDIATE
: REST-XY  S" 2R> AT-XY" EVALUATE ; IMMEDIATE
: PROMPT  ( -- ) 0 23 AT-XY VBLANKLN ;

: SOL ( -- Vaddr) 0 VROW @ >VPOS ;
: EOL ( -- n) SOL C/L@ V-TRAILING NIP ;

: +PLACE  ( addr n $ -- ) \ append addr,n to counted string $
  2DUP 2>R  COUNT +  SWAP MOVE 2R> C+! ;

\ CURSORS are fixed in the VI99FONT file.
\ These are for when FONT file is not found 
HEX
 CREATE PATTERNS
 ( solid) 00FF , FFFF , FFFF , FF00 ,
 ( bar)   7070 , 7070 , 7070 , 7070 ,
 ( box)   00FC , 8484 , 8484 , FC00 ,

: NEW-CURSORS    PATTERNS 8E8 3 8* VWRITE ;

HEX
: CURSOR ( c --)  CURS ! ;
\ cursor characters
5F CONSTANT uLINE
1E CONSTANT BAR
1F CONSTANT BOX
1D CONSTANT SOLID

DECIMAL
\ top 22 lines is the editor screen 
  C/SCR @ C/L@ 2* - CONSTANT SCRSIZE
  SCRSIZE C/L@ -    CONSTANT BOTTOMLINE 

\ fast screen write with column update 
: FASTTYPE  ( $ len ) VPOS SWAP VWRITE ; \ doesn't change VCOL 
: WRITELN   ( $ len ) DUP>R FASTTYPE R> VCOL +! ;

\ does not change cursor 
: AT-TYPE ( addr len col row -- ) >VPOS SWAP VWRITE ;  

\ VDP-to-VDP memory movement via the DATA stack :)
: VDPTYPE ( Vaddr len ) 0 ?DO VCOUNT (EMIT) LOOP DROP ;

\ clears top 22 lines ie: editing screen
: CLS  ( --) VTOP @ SCRSIZE VBLANK ;

: TEMP   HERE 100 + ;

: SCROLLDN ( line# --)
  C/L@ * DUP>R ( R: Vaddr )        \ address of video screen 
  SCRSIZE OVER -  TEMP SWAP VREAD  \ copy screen to temp buffer 
  TEMP R@ C/L@ +  SCRSIZE OVER - VWRITE
  R> C/L@ VBLANK ;                 \ erase last line 

: SCROLLUP ( line# --)
  C/L@ * DUP>R  ( R: Vaddr )
  ( Vaddr) SCRSIZE OVER -  TEMP  SWAP VREAD
  TEMP  R> C/L@ -   SCRSIZE OVER - VWRITE
  BOTTOMLINE C/L@ VBLANK ;

: LIST  ( -- )
  SAVE-XY
  CLS  0 0 AT-XY
  TXTBUFFER TOPLINE @ NTH
  22 0
  DO
    DUP         ( -- txtbuff txtbuff )
    DUP LEN  
    IF    COUNT VPOS SWAP VWRITE 
    ELSE  [CHAR] ~ VPUT  DROP 
    THEN  (CR) DROP 
    NEXT$       ( follow the link)
  LOOP 
  DROP
  REST-XY ;

\ cursor movement controls
DECIMAL
21 CONSTANT LASTROW 
: LIMITED ( n -- n')  1  LINES @ LASTROW - CLIP ;
: TOPLINE+! ( n --) TOPLINE @ +  LIMITED   TOPLINE ! ;
: MOVESCR   ( n --) TOPLINE+! LIST ;

: INS/DEL
  INSERTING @ -1 XOR INSERTING !
  INSERTING @
  IF    BAR CURSOR
  ELSE  uLINE CURSOR
  THEN ;

\ text on screen, "right of cursor" as a VDP stack string
: RIGHTSIDE ( -- VDPaddr len) SOL SCRWIDTH 1- VCOL @ /STRING ;

\ =======================
\ text manipulation
: DELCHAR    ( -- )
  PAD C/L@ 2+ BLANK         \ init pad to all spaces  
  RIGHTSIDE TUCK 1 /STRING  \ TUCK length, cut off first character  
  PAD SWAP  VREAD           \ read shortened string to PAD buffer  
  PAD VPOS ROT VWRITE ;     \ write it back to screen 

\ get VDP string into CPU RAM as a counted string 
: V$PLACE ( Vaddr len addr -- )  2DUP C! 1+ SWAP VREAD ;

: PUSHRIGHT ( -- )
  RIGHTSIDE TUCK  ( -- len Vaddr len )
  PAD SWAP VREAD              \ read VDP string into PAD buffer 
  BL VPUT                     \ write blank at cursor
  PAD VPOS 1+ ROT 1- VWRITE ; \ write buffer back to screen in new position 

\ return buffer address of edit line
: ELINE$ ( -- Caddr) 'ELINE @ ;

\ seek to the address of the ELINE#
\ REMEMBER the line# and the address
: GOTOLN    ( ln# -- $addr)
  DUP LINE# !
  TXTBUFFER SWAP NTH DUP 'ELINE ! ;

\ ====================================================
\ *NEW* line stack for cut/paste
HEX 
200          CONSTANT VSTKSIZE
VDPTOP PSZ - CONSTANT VSTACK  \ leave room for 1 PAB (PSZ is pab size) 
VARIABLE VSP                  \ Stack pointer for VDP stack  

\ integer stack in VDP RAM
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

\ ===================================================
DECIMAL
CREATE FILENAME  16 ALLOT

FILENAME OFF
: QUOTE  ( -- ) [CHAR] " (EMIT) ;
: "TYPE" ( addr len --) QUOTE WRITELN QUOTE ;

\ line# of the cursor in the _editor window_
: ELINE#  ( -- n ) TOPLINE @  VROW @  + ;

\ using WRITELN for faster refresh
: .LINES     LINES @ (.) WRITELN   S"  lines, " WRITELN ;
: .FSIZE     FSIZE   (.) WRITELN   S"  chars" WRITELN ;

: .FILE ( -- )
  FILENAME COUNT DUP 0=
  IF 2DROP S" new file" THEN PROMPT "TYPE" ;

: [COL!]  ( n --) 0 EOL CLIP VCOL ! ; \ save column to EOL or less 

: .CLIP   69 VCOL !   S" Clip: " WRITELN  LDEPTH . ;

: .STACK  S"  STK=" WRITELN DEPTH (.) WRITELN ;

: .FSTATS
  DECIMAL 
  SAVE-XY
  .FILE SPACE .LINES .FSIZE SPACE .STACK .CLIP 
  REST-XY ;

\ ===[ "INSERT" MODE primitives ]===
: SCR$ ( -- Vaddr len) SOL C/L@ V-TRAILING 1 MAX ;


\ open space for a string in HEAP, write Vstring to Heap, re-allocate 
: INSERT-TEXT ( Vaddr len line# --)
  OVER >R                                \ LEN to rstack 
  GOTOLN DUP>R ( Vaddr len $ ) ( r: eline$)
  OVER R@ + 1+ ( Vaddr len $ $+len+1 )
  HEAP R@ - 0 MAX  ( Vaddr len $ $' size ) MOVE \ open space for string

  R> V$PLACE                              \ write new string to HEAP 
  R> 1+ HALLOT ;                          \ update HEAP size 

\ write a line from screen (VDP RAM) back into txtbuffer 
: WRITEBACK ( Vaddr len line# -- Vaddr)
  OVER >R                                \ LEN to rstack 
  GOTOLN DUP>R ( len $ ) ( r: eline$)
  DUP NEXT$ SWAP
  2 PICK + 1+
  HEAP OVER - 0 MAX 2+ MOVE 
  R> V$PLACE 
  R> HALLOT ;

: RELINE ( -- ) SCR$ ELINE# WRITEBACK ; \ writeback current line 

VARIABLE NEWTEXT?  \ true if open command used

: UPDATELN  
  SCR$ ELINE# ( -- Vaddr len line# )
  NEWTEXT? @
  IF   INSERT-TEXT  LINES 1+!      
  ELSE WRITEBACK 
  THEN ;

: DELLN ( lnaddr-- len )
  DUP NEXT$ SWAP  ( $2 $1)
  DUP C@ 1+ DUP>R ( $2 $1 len)
  FSIZE SWAP -  MOVE
  R> ;

: DEALLOT ( n -- )
  HEAP OVER - C/L@ ERASE    \ set end of heap to zeros  
  HEAP SWAP - TXTBUFFER MAX H ! ;  \ deallocate

: DELETELN ( lnaddr -- n) DELLN  DEALLOT  LINES DECR ;

: DEL-LINE# ( ln# --) GOTOLN DELETELN ;

\ text/screen color combos
HEX
\ 17 CONSTANT BLK/CYAN
\ E4 CONSTANT WHT/BLU
\ 21 CONSTANT MEDGRN/BLK
\ 31 CONSTANT LTGRN/BLK
C1 CONSTANT DKGRN/BLK
E1 CONSTANT GRAY/BLK

DECIMAL
: SCREEN  ( c -- ) 7 VWTR ;

: NEW-FILE 
  CLS  
  TXTBUFFER 8K PURGE
  FILENAME OFF  
  1 TOPLINE ! ;

: ?DOT   ( $ len -- $ len) 
  2DUP  [CHAR] . SCAN NIP 0= ABORT" Missing '.'" ;

: SAVE  ( -- )  
  READONLY @ IF PROMPT ." Mode is READONLY" 1000 MS  END   
  FILENAME COUNT WRITE-FILE ;

\ ========================
\ get current drive string
\ ========================
DECIMAL
24 USER 'R12  \ access register 12 as a user variable. ;-) 

HEX
CODE 0SBO  ( -- ) 1D00 ,  NEXT, ENDCODE
CODE 0SBZ  ( -- ) 1E00 ,  NEXT, ENDCODE

\ for reference. Save space by not declaring constants 
\ 83D0 CONSTANT DISKCARD
\ 83D2 CONSTANT DEVLIST

CREATE $HOME 8 ALLOT

: GETDEV  (  --) \ $HOME will contain "DSK1." 
  83D0 @ 'R12 !
  0SBO
  83D2 @ 4 + COUNT $HOME PLACE
  0SBZ
  S" ." $HOME +PLACE \ add the '.' char
;

\ append missing path to a filename 
: +PATH ( addr len -- addr' len') \ add disk path if missing from filename 
  2DUP [CHAR] . SCAN NIP 0=       \ scan for '.' char 
  IF                              \ if '.' not found  
  \ PAD OFF                       \ set pad length to zero  
    $HOME COUNT PAD PLACE         \ place the current drive string in PAD 
   ( addr len ) PAD +PLACE        \ append the given string argument 
    PAD COUNT                     \ return the full path as stack string pair
  THEN                                 
;

\ ====================================
\ number argument collector uses a counted string to hold digits
DECIMAL 
CREATE ArgBUFF 6 ALLOT    ArgBUFF 6 0 FILL 

\ append char to buffer 
: ARG$+   ( char -- ) HERE C!  HERE 1 ArgBUFF +PLACE ; 
: CLRARG  ( -- ) 0 ArgBUFF C! ;

: ARG#    ( -- n) \ n always 1 or more 
  ArgBUFF COUNT NUMBER? ( n ?) \ ?=0 means valid conversion
  IF   DROP HONK CLRARG 0  
  ELSE 0 MAX 
  THEN ;


\ if key is a digit, accumulate as a decimal number
: ACCUMULATE ( char -- char' )
  GCHAR >R                    \ remember char under cursor
  CLRARG ARG$+                \ it's number key so start a new arg string 
  BEGIN 
    KEY DUP 
    [CHAR] 0 [CHAR] 9 BETWEEN \ get next key, 0 is valid, test for digit 
  WHILE                       \ while it is a digit 
    ARG$+                     \ append to ARG$ 
  REPEAT                      \ end loop and return last key value  
  R> VPUT                     \ put char back
;

HEX 
: CMDKEY ( -- char ) \ accumulate numbers or return key stroke 
  GETKEY
  DUP [CHAR] 1 [CHAR] 9 BETWEEN 
  IF ACCUMULATE END
; 

DECIMAL
15 CONSTANT <ESC>

\ Command mode KEY commands
\ Ideas from VIBE by Sam Falvo
\ Word name key:  $$ _ - _
\                    |   |
\ c = command mode --+   |
\ i = ins/repl mode      |
\                        |
\ ASCII code       ------+
\

\ ===================================
\ undo function 
DECIMAL
CREATE UBUFFER  82 ALLOT

: SAVEUNDO ( --) SCR$ UBUFFER V$PLACE ;

: $$c-u  ( --)  
   SCR$ PAD V$PLACE                \ move scr$ to CPU RAM for comparison 
   PAD COUNT UBUFFER COUNT COMPARE \ is Ubuffer different than the screen?
   IF  UBUFFER COUNT SOL SWAP VWRITE  RELINE  THEN ;

\ =================================
\ other formatted commands for the interpreter
: DELWORD   BEGIN  DELCHAR  GCHAR BL =  UNTIL ; 

: CUTLINE ( line# -- ) DUP PUSHLN DEL-LINE# ;

: CUTLINES  ( -- ) 
  SAVE-XY
  ARG# 0= 
  IF  ELINE# CUTLINE 
  ELSE 
    ARG#  LINES @ MIN 0 ?DO  ELINE# CUTLINE .FSTATS  LOOP 
  THEN LIST 
  REST-XY 
;

: $$c-x ( -- ) SAVEUNDO DELCHAR UPDATELN ;

: DELWORDS  
  ARG# 0= IF DELWORD UPDATELN END 
  ARG# 0 ?DO  DELWORD  LOOP  UPDATELN ;

HEX 
: $$c-d   \ delete command is a SUB-interpreter
  SAVEUNDO 
  WAITKEY ( -- char)
  CASE 
      [CHAR] d OF  CUTLINES  ENDOF 
      [CHAR] w OF  DELWORDS  ENDOF 
  ENDCASE ;
DECIMAL 

: $$c-D
  SAVEUNDO 
  RIGHTSIDE VBLANK  UPDATELN ;

\ command mode cursor control
: $$c-h \ Cleft
 ARG# 0= IF  VCOL DECR  END 
 ARG# 1+ 0 ?DO VCOL DECR LOOP ;

: CUP  
  VROW DUP 1-! @ DUP 0< 
  IF -1 MOVESCR  
  THEN  0 MAX VROW !  
        VCOL @  [COL!] ;

: $$c-k  
  ARG# 0= IF CUP END 
  ARG# 1+ 0 ?DO  CUP  LOOP ;

: CDOWN
   H @ 16384 > ABORT" Memory full" 
   VROW @ 1+ 
   DUP LASTROW >
   IF 1 MOVESCR 
   THEN LASTROW MIN LINES @ MIN VROW !  \ limit VROW to LASTROW
   VCOL @  [COL!]               \ don't go past end of line 
 ;

: $$c-j  
  ARG# 0= IF CDOWN END 
  ARG# 1+ 0 ?DO  CDOWN  LOOP ;

: COPYLN    ELINE# PUSHLN CDOWN ;

: $$c-y  
  WAITKEY [CHAR] y <> IF END
  SAVE-XY
  ARG# 0= 
  IF   COPYLN  
  ELSE ARG# 0
       ?DO  
         COPYLN  
       LOOP 
  THEN 
  REST-XY ; 

: CRIGHT   VCOL @ 1+  [COL!] ;

: $$c-l 
  ARG# 0= IF CRIGHT END  
  ARG# 1+ 0 ?DO  CRIGHT LOOP ;

: $$c-$  EOL VCOL !  ;

: $$c-0  VCOL OFF ;

: $$c-J ( -- ) \ join lines 
  VCOL @ 1+ >R 
  CDOWN ELINE# CUTLINE 
  CUP   
  R@ VCOL !  VSTK> VCOUNT VDPTYPE UPDATELN 
  R> VCOL ! 
  LIST 
;

: $$c-:
  SAVE-XY
  PROMPT ." :"
  TIB DUP C/L@ 2-  ACCEPT  EVALUATE
  LIST
  REST-XY 
;

\ OVERWRITE single char
: $$c-r
  SAVEUNDO 
  INSERTING OFF
  uLINE CURSOR  GETKEY VPUT
  UPDATELN ;

: $$c-G ( n -- )
  ARG# DUP 
  IF ( ARG#>0 )
    LIMITED TOPLINE ! 
    0 0 AT-XY 
  ELSE ( ARG#=0 ) 
    DROP   
    LINES @ 22 - 1 MAX TOPLINE !  
    0  LASTROW LINES @ 1- MIN  AT-XY 

  THEN LIST  
;

: ERASE~ \ erase ~ if found
  SOL VC@ [CHAR] ~ =
  IF  BL SOL VC!  UPDATELN  THEN ;

: BACK-SPACE   
  VCOL DUP 1-! @ ( -- vcol)
  DUP -1 > IF  DELCHAR  THEN [COL!] ;  

: OPEN-LINE ( -- ) VROW @ SCROLLDN  NEWTEXT? ON ; 

: ASCII?    ( c -- ?) BL [CHAR] ~ BETWEEN ;

: ENTER
    RIGHTSIDE 2DUP PAD V$PLACE  \ copy rightside to pad
    VBLANK                      \ erase rightside on screen
    UPDATELN                    \ update changed line        
    CDOWN ERASE~
    OPEN-LINE                   \ open a new-line on screen 
    $$c-0                       \ goto start of line
    PAD COUNT FASTTYPE          \ write pad to newline on screen 
;

\ ======================
\ on screen line editor
\ ======================
DECIMAL
: EDITLN ( column -- )
  VCOL ! 
  GRAY/BLK SCREEN
  BEGIN
    ERASE~
    GETKEY
    DUP ASCII? 
    IF
      INSERTING @ IF PUSHRIGHT THEN CPUT DROP 
      VCOL @ SCRWIDTH MIN VCOL ! 
    ELSE
      CASE
       ^ C OF  DELCHAR            ENDOF
       ^ D OF  INS/DEL            ENDOF
       ^ H OF  BACK-SPACE         ENDOF

       ^ M OF  ENTER              ENDOF

     <ESC> OF  UPDATELN 
               NEWTEXT? OFF 
               EXIT               ENDOF

      ( otherwise:) HONK
    ENDCASE
    
    THEN .FSTATS
  AGAIN
;

\ ==================================================
\ editing commands
: $$c-i     \ insert text at cursor  
  SAVEUNDO 
  INSERTING ON  BAR CURSOR  ERASE~
  VCOL @ EDITLN ;

: $$c-I     \ edit from start of line 
  SAVEUNDO
  INSERTING ON  BAR CURSOR   ERASE~   0 EDITLN ;

: $$c-O   OPEN-LINE  $$c-I ;  \ open new line above cursor 
: $$c-o   CDOWN      $$c-O ;  \ open new line below cursor 
 

\ **IMPORTANT** 
\ Since the VDP screen is the buffer we only need to type the
\ stack string to the screen and call UPDATELN 
: INSERTLN# ( Caddr len -- )
  OPEN-LINE 
  0 VROW @ AT-XY  VSTK> VCOUNT VDPTYPE 
  UPDATELN 
  .FSTATS 
  VCOL OFF ;

: $$c-P \ paste clipboard ABOVE cursor 
  LDEPTH 0= IF  BEEP  END
  SAVE-XY
  LDEPTH  0 ?DO  INSERTLN#  LOOP
  REST-XY
  KILL-BUFFER ;

: $$c-p  CDOWN $$c-P ; \ past clipboard BELOW cursor 

: $$c-r \ OVERWRITE 1 char
  SAVEUNDO  
  CURS @ >R
  uLINE CURSOR  GETKEY EMIT UPDATELN
  R> CURSOR ;

: OVERWRITE ( vcol -- ) SAVEUNDO  INSERTING OFF  uLINE CURSOR EDITLN ;  

: $$c-R   VCOL @         OVERWRITE ; \ "replace" text at cursor 
: $$c-a   VCOL DUP 1+! @ OVERWRITE ; \ append @ curs + 1
: $$c-A   EOL            OVERWRITE ; \ overwrite line

\ : VSKIPBL  ( Vaddr len --)
\    BEGIN  
\      DUP 
\    WHILE 
\      OVER VC@ BL =
\    WHILE 
\      1 /STRING 
\    REPEAT
\    THEN  
\ ;

\ : VSCAN2BL ( Vaddr len --)
\    BEGIN 
\      DUP 
\    WHILE 
\      OVER VC@ BL <>
\    WHILE 
\      1 /STRING 
\    REPEAT
\    THEN  
\ ;

\: -ASCII ( addr len -- addr len') \ scan back until BL
\    1- 0 MAX 
\    OVER + ( start end )
\    BEGIN 
\       2DUP <> 
\    WHILE           \ test end of string 
\       DUP C@ BL <> 
\    WHILE           \ test for blank 
\        1-          \ dec address 
\    REPEAT 
\    THEN 
\    OVER - 0 MAX 
\ ;    

\ : $$c-w   VSKIPBL  VSCAN2BL  ;

\ ===========================
\ Editor Key Handler
\ CMD$ is built as a string with ascii key value appended 
\ then found and executed by Forth interpreter
HEX
     FF CONSTANT $FF
CHAR i  CONSTANT 'i   \ Insert mode
CHAR c  CONSTANT 'c   \ Command mode

'c MODE !
CREATE CMD$
5 C,
CHAR $ C, CHAR $ C, 'c C,
CHAR - C,  0 C,

DECIMAL
: CMD? ( --?) MODE @ 'c = ;
: INS? ( --?) MODE @ 'i = ;

: MODE! ( c --) INS? 'i AND CMD? 'c AND OR   CMD$ 3 + C! ;
: ASCII! ( c --) $FF AND CMD$ 5 + C! ;
: CMD!   ( c -- )  MODE! ASCII! ;

\ ===================
\ HANDLER: the command interpreter
\ ===================
: HANDLER ( k -- )
  CMD!
  CMD$ FIND 0= IF  DROP BEEP END
  EXECUTE 
  CLRARG 
;

: SCR-SETUP 
  INSERTING ON
  1 TOPLINE ! 
  0 22 HLINE
  LIST  0 0 AT-XY 
  'c MODE ! ;

DECIMAL
21 CONSTANT 1SCR
11 CONSTANT 1/2SCR

\ ===[ VI Command Mode keys ]===
\ command to edit existing buffer
: edit ( -- )
  SCR-SETUP
  CLRARG 
  BEGIN
    DKGRN/BLK SCREEN
    .FSTATS
    BOX CURSOR 
    CMDKEY
    CASE
     \ control keys
      ^ F OF  1SCR MOVESCR          ENDOF
      ^ B OF  1SCR NEGATE MOVESCR   ENDOF
      ^ D OF  1/2SCR MOVESCR        ENDOF
      ^ U OF  1/2SCR NEGATE MOVESCR ENDOF
      ^ L OF  LIST  0 22 HLINE      ENDOF
      ^ M OF  CDOWN $$c-0           ENDOF
       BL OF  $$c-l                 ENDOF  ( Cursor right)
      ^ Z OF  PAGE ." VI99 Shell" ABORT ENDOF
      ^ K OF  KILL-BUFFER           ENDOF 
     \ Default: Command interpreter
              DUP HANDLER
    ENDCASE 
  AGAIN ;

\ ==========================
\ Additional shell commands
\ ==========================
VOCABULARY EDITOR
ONLY FORTH ALSO EDITOR DEFINITIONS

INCLUDE DSK4.VILS
INCLUDE DSK4.VILS-L
INCLUDE DSK4.VIRM
INCLUDE DSK4.FONTLOADER 

HEX 
: TRY-FONT    
  S" VI99FONT" +PATH TOUPPER LOAD-FONT 
  IF HONK  PROMPT ." Font file not found "  400 MS  THEN ;
DECIMAL 

\ ======================================
\ ===[ vi style user commands ]===

: x   PROMPT ." Saving..." SAVE  uLINE CURSOR CR ABORT ;
: q   x  ;
: q!  uLINE CURSOR  CR ." Not saved"   ABORT ;
: w   PARSE-NAME DUP IF  +PATH FILENAME PLACE  THEN SAVE ;
: w!  READONLY OFF w ;
: wq  x q ;

\ 123 G *MUST have space after no. if used on command line
: G    ( n -- ) 1-  1 LINES @ CLIP  TOPLINE ! LIST ;
: 1G     1 G ;
: $      LINES @  G ;

\ ==========================
: (vi) ( addr len -- )
  DUP 0=
  IF
    2DROP NEW-FILE
  ELSE 
    TOUPPER +PATH ( addr len )
    2DUP FILENAME PLACE  
    READ-FILE
  THEN edit ;

: -R    READONLY ON ; 
: -M    READONLY OFF ;

: vi    PARSE-NAME -M  (vi) ; 
: e     vi ;   
: view  PARSE-NAME -R (vi) ;
: help  S" VIMANPAGE" -R (vi) ;
: cd     PARSE-NAME ?DOT TOUPPER  $HOME PLACE ;
: font   PARSE-NAME +PATH TOUPPER LOAD-FONT ?FILERR  ;
: //     edit ;
: bye    BYE ;
: cold   COLD ;
: clear  PAGE ;

  ONLY FORTH ALSO EDITOR ALSO FORTH DEFINITIONS
\ console REPL with prompt for vi99
DECIMAL 
: prompt$  CR  $HOME .$  ." $ " ;

: NEWQUIT 
  RP0 RP! L0 LP !
  SOURCE-ID OFF
  POSTPONE [
  BEGIN
    prompt$  TIB DUP 82 ACCEPT SPACE
    ( addr len) INTERPRET
  AGAIN ;

\ Boot the program 
: VI99
  WARM 
  INIT-WORDLISTS
  ONLY FORTH DEFINITIONS ALSO EDITOR 
  DECIMAL 
  
  KILL-BUFFER 
  GETDEV 

  80COLS  
  DKGRN/BLK SCREEN
  TRY-FONT 
  NEW-CURSORS
  uLINE CURSOR
  ['] NEWQUIT ['] QUIT CELL+ !  \ patch quit (Forth interpreter)

  READONLY OFF 
  NEWTEXT? OFF 

  PAGE ." VI99 Command Shell 1.43g 2023   Brian Fox"
  CR
  CR ." help to see manpage"
  CR ." ls or ls-l to see files on disk"
  CR ." cd dsk?.  to change disk"
  CR ." vi <path> to edit a file"

  CR ." Type bye to exit vi99 shell"

  ABORT ;

HERE SWAP - DECIMAL .

 LOCK ( *** MUST RUN LOCK BEFORE INVOKING VI99 ** )




 INCLUDE DSK1.SAVESYS
 
 ' VI99 SAVESYS DSK4.VI9980

NEW-CURSORS
ALSO EDITOR
