\ VI99.FTH  editor for TI-99 V 1.43    Jan 2023 

\ ** requires F18A 80 column video card **

\ Sept 7, 2022 Brian Fox
\ VI99 concepts:
\ Use VI key mappings.
\ Use Forth interpreter
\ Commands created from key value
\ Read files into low ram
\ Edit text directly in VDP RAM (TI-99 screen)
\ Changes:
\ GOTO is the G command
\ goto the line & remember the address
\ ---------------------------------------------
\ *i – Insert at cursor (goes into insert mode)
\ *a – Write after cursor (goes into insert mode)
\ *A – Write at the end of line (goes into insert mode)
\ *ESC – Terminate insert mode
\ u – Undo last change
\ U – Undo all changes to the entire line
\ *o – Open a new line (goes into insert mode)
\ dd – Delete line
\ 3dd – Delete 3 lines.
\ D – Delete contents of line after the cursor
\ C – Delete contents of a line after the cursor and insert new text.
\     Press ESC key to end insertion.
\ dw – Delete word
\ 4dw – Delete 4 words
\ cw – Change word
\ x – Delete character at the cursor
\ r – Replace character
\ R – Overwrite characters from cursor onward
\ s – Substitute one character under cursor continue to insert
\ S – Substitute entire line and begin to insert at the beginning of the line
\ yy - CUT line to clipboard 
\ G  - goto line
\ ~ – Change case of individual character

NEEDS WORDLIST   FROM DSK1.WORDLISTS
ONLY FORTH DEFINITIONS
 NEEDS DUMP       FROM DSK1.TOOLS
NEEDS READ-LINE  FROM DSK1.ANSFILES
NEEDS #1         FROM DSK4.HEAPSTRINGS
NEEDS CASE       FROM DSK1.CASE
NEEDS RKEY       FROM DSK1.RKEY
NEEDS -TRAILING  FROM DSK1.TRAILING
NEEDS MOVE       FROM DSK1.MOVE
NEEDS MARKER     FROM DSK1.MARKER
NEEDS 80COLS     FROM DSK1.80COL

MARKER VI99

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
VARIABLE 'ELINE  \ address of line# in HEAP
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

HEX
: GETKEY ( -- c) RKEY 7F AND ; \ c is 7 bit ascii 

: VALIDATE ( char $ len -- ?) ROT SCAN NIP ; \ char a S" abcded" VALIDATE 

\ handy macro
: END
  POSTPONE EXIT
  POSTPONE THEN ; IMMEDIATE

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
: SCRLINE ( -- Vaddr) VROW @ C/L@ * ;

: +PLACE  ( addr n $ -- ) \ append addr,n to counted string $
  2DUP 2>R  COUNT +  SWAP MOVE 2R> C+! ;

\ fix cursors and hi-lighter char for 40/80 column mode 
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
: VTYPE ( $ len )
  DUP>R VPOS SWAP VWRITE R> VCOL +! ;

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
  TXTBUFFER TOPLINE @ NTH
  SAVE-XY
  CLS  0 0 AT-XY
  22 0
  DO
    DUP         ( -- txtbuff txtbuff )
    COUNT DUP  
    IF    -TRAILING VPOS SWAP VWRITE 
    ELSE  [CHAR] ~ VPUT 2DROP 
    THEN  (CR) DROP 
    NEXT$       ( follow the link)
  LOOP 
  DROP
  REST-XY ;

\ cursor movement controls
: TOPLINE+! ( n --) TOPLINE @ SWAP +  0 2000 CLIP  TOPLINE ! ;
: MOVESCR   ( n --) TOPLINE+! LIST ;

DECIMAL
: INS/DEL
  INSERTING @ -1 XOR INSERTING !
  INSERTING @
  IF    BAR CURSOR
  ELSE  uLINE CURSOR
  THEN ;

\ text on screen, "right of cursor" as a VDP stack string
: RIGHTSIDE ( -- VDPaddr len) SCRLINE C/L@  VCOL @ /STRING ;

\ =======================
\ text manipulation
: DELCHAR    ( -- )
  PAD C/L@ 2+ BLANK         \ init pad to all spaces  
  RIGHTSIDE TUCK 1 /STRING  \ cut off first character  
  PAD SWAP  VREAD           \ read shortened string to PAD buffer  
  PAD VPOS ROT VWRITE ;     \ write it back to screen 

\ get VDP string into CPU RAM as a counted string 
: V$@ ( Vaddr len addr -- )  2DUP C! 1+ SWAP VREAD ;


: PUSHRIGHT ( -- )
  RIGHTSIDE TUCK  ( -- len Vaddr len )
  PAD SWAP VREAD              \ read VDP string into PAD buffer 
  BL VPUT                     \ write blank at cursor
  PAD VPOS 1+ ROT 1- VWRITE ; \ write buffer back to screen in new position 

\ return buffer address of edit line
: ELINE$ ( -- Caddr) 'ELINE @ ;

\ seek to the address of the ELINE#
\ REMEMBER the line# and the address
: GOTOLN    ( ln# --)
  DUP LINE# !
  TXTBUFFER SWAP NTH 'ELINE ! ;


\ ========================
\ line stack for cut/paste
HEX
1000 CONSTANT STKBASE \ ** VDP address **

DECIMAL
  C/L@ CONSTANT STKWIDTH
STKBASE STKWIDTH 100 * CONSTANT STKEND

CREATE LSTK  STKBASE ,

: LNPUSH   STKWIDTH LSTK +! ;
: LNPOP    STKWIDTH NEGATE LSTK +! ;

: VTOS$    ( -- Vaddr) LSTK @ ;
: LDEPTH   ( -- n) VTOS$ STKBASE - STKWIDTH / ;
\ : KILL-BUFFER ( --)   STKBASE LSTK ! ; \ clear line-stack

: STKFULL?  (  -- ?) \ ?=true if full 
  VTOS$ STKWIDTH +  STKBASE STKEND BETWEEN 0= ;

  DECIMAL
: PUSHLN ( line# -- ) \ push Line# onto line stack 
  GOTOLN
  ELINE$ COUNT LNPUSH VTOS$ VPLACE 
;

: KILL-BUFFER ( -- ) STKBASE LSTK ! ; \ reset pointer 


DECIMAL
CREATE FILENAME  16 ALLOT

FILENAME OFF
: QUOTE  ( -- ) [CHAR] " (EMIT) ;
: "TYPE" ( addr len --) QUOTE VTYPE QUOTE ;

\ line# of the cursor in the _editor window_
: ELINE#  ( -- n ) TOPLINE @  VROW @  + ;

\ using VTYPE for faster refresh
: .LINES     LINES @ (.) VTYPE   S"  lines, " VTYPE ;
: .FSIZE     FSIZE   (.) VTYPE   S"  chars" VTYPE ;

: .FILE ( $ -- )
  FILENAME COUNT DUP 0=
  IF 2DROP S" new file"
  THEN PROMPT "TYPE" ;

: .CLIP   69 VCOL !  S" Clip: " VTYPE  LDEPTH .  ;

: .FSTATS
  DECIMAL 
  SAVE-XY
  .FILE SPACE .LINES .FSIZE  .CLIP 
  REST-XY ;

\ ===[ "INSERT" MODE primitives ]===

\ V-trailing removes trailing blanks, for a VDP string
: V-TRAILING ( V$ len -- V$ len')
  1-
  BEGIN
     2DUP + VC@ BL =
  WHILE
     1-
  REPEAT
  1+ ;


: SCR$ ( -- Vaddr len)
  SCRLINE C/L@ V-TRAILING 1 MAX ;

: EOL ( V$ -- n) C/L@ V-TRAILING NIP ;


\ open space for a string in HEAP
\ return the HEAP address
: MAKEROOM ( len line# -- addr)
  OVER 1+ HALLOT
  GOTOLN
  ELINE$ DUP>R ( len $ ) ( r: eline$)
  OVER R@ + 1+ ( len $ $+len+1 )
  HEAP R@ - 0 MAX  ( len $ $' size )
  MOVE R> ;

\ store VDP string at addr in CPU RAM
: V$>HEAPLN ( Vaddr len ELINE# --) MAKEROOM  V$@    LINES 1+! ;

\ write a line from screen (VDP RAM) back into txtbuffer 
: WRITEBACK ( len line# -- Vaddr)
  GOTOLN
  ELINE$ DUP>R
  DUP NEXT$ SWAP
  2 PICK + 1+
  HEAP OVER - 0 MAX 2+ MOVE R> ;

: DELLN ( lnaddr-- len )
  DUP NEXT$ SWAP  ( $2 $1)
  DUP C@ 1+ DUP>R ( $2 $1 len)
  FSIZE SWAP -  MOVE
  R> ;

: DEALLOT ( n -- )
  HEAP OVER - C/L@ ( 2*) ERASE    \ set end of heap to zeros  
  HEAP SWAP - TXTBUFFER MAX H ! ;  \ deallocate

: DELETELN ( lnaddr -- n) DELLN  DEALLOT  LINES DECR ;

: DEL-LINE# ( ln# --) GOTOLN ELINE$ DELETELN ;

: UPDATELN  SCR$ DUP>R ELINE# WRITEBACK V$@     R> HALLOT ;

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
  FILENAME OFF  TOPLINE OFF ;

: ?DOT   ( $ len -- $ len) 
  2DUP  [CHAR] . SCAN NIP 0= ABORT" Missing '.'" ;

: SAVE  ( -- )  
  READONLY @ IF PROMPT ." READONLY is ON" 1000 MS  END   
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

CREATE HOME$ 8 ALLOT

: GETDEV  (  --) \ HOME$ will contain "DSK1." 
  83D0 @ 'R12 !
  0SBO
  83D2 @ 4 + COUNT HOME$ PLACE
  0SBZ
  S" ." HOME$ +PLACE \ add the '.' char
;

\ append missing path to a filename 
: +PATH ( addr len -- addr' len') \ add disk path if missing from filename 
  2DUP [CHAR] . SCAN NIP 0=       \ scan for '.' char 
  IF                              \ if '.' not found  
  \ PAD OFF                       \ set pad length to zero  
    HOME$ COUNT PAD PLACE         \ place the current drive string in PAD 
   ( addr len ) PAD +PLACE        \ append the given string argument 
    PAD COUNT                     \ return the full path as stack string pair
  THEN                                 
;

\ ====================================
\ number argument collector uses a counted string to hold digits
DECIMAL 
CREATE ArgBUFF 6 ALLOT    ArgBUFF 6 0 FILL 

: ARG$+   ( char -- ) HERE C!  HERE 1 ArgBUFF +PLACE ; \ append char to buffer 
: CLRARG  ( -- ) 0 ArgBUFF C! ;

: ARG#    ( -- n) \ n always 1 or more 
  ArgBUFF COUNT NUMBER? ( n ?) \ ?=0 means valid conversion
  IF   DROP HONK CLRARG 0  
  ELSE 0 MAX 
  THEN ;

: ACCUMULATE ( char -- char' )
  CLRARG ARG$+                \ number  key so start a new arg string 
  BEGIN 
    KEY DUP 
    [CHAR] 0 [CHAR] 9 BETWEEN \ get next key, 0 is valid, test for digit 
  WHILE                       \ while it is a digit 
    ARG$+                     \ append to ARG$ 
  REPEAT ;                    \ end loop and return last key value  

HEX 
: CMDKEY ( -- char ) \ accumulate numbers or return key stroke 
  BEGIN KEY? ?DUP UNTIL 07F AND 
  DUP [CHAR] 1 [CHAR] 9 BETWEEN 0= IF END  \ NOT 1..9 key, just return key value 
  ACCUMULATE 
; 

DECIMAL
13 CONSTANT ^M 
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

: SAVELN    SCRLINE UBUFFER  C/L@ VREAD ;
: UNDO      UBUFFER SCRLINE  C/L@ VWRITE UPDATELN ;

: $$c-u  UNDO  ; \ define command for interpreter


\ =================================
\ other formatted commands for the interpreter

: CUTLINE ( -- ) \ Cut and put into clipboard 
  STKFULL? IF BEEP END 
  SAVE-XY
  ELINE# DUP PUSHLN DEL-LINE#  
  LIST  
  REST-XY ;

: ARG#DO  S" ARG# 1+ 0 DO" EVALUATE ;  IMMEDIATE 

: CUTLINES  ( -- ) ARG#DO  CUTLINE LOOP  ;

: $$c-x ( -- ) SAVELN DELCHAR UPDATELN ;

\ vdp screen is the actual editing buffer so we use the cursor VDP address
: READCHAR  ( -- c ) VPOS VC@ ; 

: DELWORD   BEGIN  DELCHAR  READCHAR BL = UNTIL UPDATELN ; 

: DELWORDS  ARG#DO  DELWORD  LOOP  ;

: $$c-d   \ delete command is a SUB-interpreter
  SAVELN 
  CMDKEY ( -- char)
  CASE 
      [CHAR] d OF  CUTLINES   ENDOF 
      [CHAR] w OF  DELWORDS   ENDOF 
  ENDCASE ;

: $$c-D
  SAVELN 
  RIGHTSIDE VBLANK  UPDATELN ;

\ command mode cursor control
: $$c-h \ Cleft
  VCOL DECR ;

: $$c-k  \ CUP
  ARG#DO 
    VROW DUP DECR
    @ 0= IF -1 MOVESCR THEN 
  LOOP 
;

\ : -EOF ( -- ?)  ELINE# LINES @ 1- < ; \ not end of file 

: CDOWN
 \ -EOF 
 \ IF  
   H @ 16384 > ABORT" Memory full" 
   VROW @ 1+ DUP 21 >
   IF 1 MOVESCR THEN 21 MIN VROW ! 
 \ THEN 
 ;

: NEWLINE  CDOWN  VCOL OFF ;

: $$c-j  ARG#DO  CDOWN  LOOP ;

: COPYLN  
  STKFULL? IF HONK END  
  ELINE# PUSHLN ;

: $$c-y  
  CMDKEY [CHAR] y <> IF END
  SAVE-XY
  ARG#DO  COPYLN CDOWN  LOOP 
  REST-XY ; 

: $$c-l  \ CRGHT
  ARG#DO 
    VCOL @ 1+ SCRWIDTH MIN  VCOL ! 
  LOOP ;

: $$c-$  SCRLINE EOL VCOL ! ;
: $$c-0  VCOL OFF ;

: $$c-:
  SAVE-XY
  PROMPT ." :"
  TIB DUP C/L@ 2-  ACCEPT  EVALUATE
  LIST
  REST-XY  ;

\ Replace single char
: $$c-r
  SAVELN 
  INSERTING OFF
  uLINE CURSOR  GETKEY VPUT
  UPDATELN  ;

: $$c-G ( n -- )
  ARG# DUP 
  IF ( ARG#>0 )
    1- 0 LINES @ CLIP  TOPLINE ! 
    0 0 AT-XY 
  ELSE ( ARG#=0 ) 
    DROP   LINES @ 22 - TOPLINE !  
    0 21 AT-XY 
  THEN LIST  
      
;

: ERASE~ \ erase ~ if found
  SCRLINE VC@ [CHAR] ~ =
  IF  BL SCRLINE VC!  UPDATELN  THEN ;

\ =====================
\ on screen line editor
\ =====================
DECIMAL
: EDITLN ( column -- )
  VCOL !
  GRAY/BLK SCREEN
  BEGIN
    ERASE~
    GETKEY
    DUP BL [CHAR] ~ BETWEEN
    IF
      INSERTING @ IF PUSHRIGHT THEN CPUT DROP
      VCOL @ C/L@ 2- MIN VCOL !
    ELSE
      CASE
       ^ C OF  DELCHAR          ENDOF
       ^ D OF  INS/DEL          ENDOF
       ^ H OF  $$c-h            ENDOF
        ^M OF UPDATELN NEWLINE  ENDOF
     <ESC> OF UPDATELN EXIT     ENDOF
        ( otherwise:) HONK
    ENDCASE
    
    THEN .FSTATS
  AGAIN
;

\ start editing commands
: $$c-i
  SAVELN 
\  KILL-BUFFER
  INSERTING ON  BAR CURSOR  ERASE~
  VCOL @ EDITLN ;

: $$c-I
 \ KILL-BUFFER
  INSERTING ON  BAR CURSOR  ERASE~
  0 EDITLN ;

: OPEN-LINE 
  VROW @ SCROLLDN
  SCRLINE C/L@ ELINE# V$>HEAPLN  ;

: $$c-o \ open new line
  OPEN-LINE  $$c-I ;

\ VDP-to-VDP memory movement :)
: VDPTYPE ( Vaddr len )
  0 ?DO VCOUNT (EMIT) LOOP DROP ;

\ **IMPORTANT** 
\ Since the VDP screen is the buffer we only need to type the
\ vtos$ string on the screen and call UPDATELN 
: INSERTLN# ( -- )
  OPEN-LINE 
  VTOS$ VCOUNT SCRWIDTH MIN VDPTYPE
  LNPOP 
  UPDATELN
  VCOL OFF ;

: $$c-p \ paste all lines, erase clipboard
  LDEPTH 0= IF  BEEP  END
  SAVE-XY 
  LDEPTH 0 ?DO  INSERTLN#  LOOP 
  REST-XY ;

 : $$c-P  \ non-standard: paste all lines. Keep clipboard 
  LDEPTH 0= IF  BEEP  END
  LSTK @ >R                       \ remember line stack position  
  LDEPTH 0 ?DO  INSERTLN#  LOOP 
  R> LSTK !                        \ restore line stack 
;

: $$c-R \ replace many chars
  SAVELN 
  INSERTING OFF
  uLINE CURSOR
  VCOL @ EDITLN ;

: $$c-r \ replace 1 char
  SAVELN 
  CURS @ >R
  uLINE CURSOR
  GETKEY EMIT UPDATELN
  R> CURSOR ;

\ append @ curs
: $$c-a  SAVELN  ( KILL-BUFFER)  VCOL @ 1+!  $$c-R ;

\ append line
: $$c-A
  SAVELN 
  INSERTING OFF
  uLINE CURSOR
  SCRLINE EOL EDITLN ;

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

: MODE! ( --)
  INS? 'i AND CMD? 'c AND OR
  CMD$ 3 + C! ;

: ASCII! ( c --) $FF AND CMD$ 5 + C! ;
: CMD!   ( -- )  MODE! ASCII! ;

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
  KILL-BUFFER
  TOPLINE OFF
  0 22 HLINE
  LIST  0 0 AT-XY 
  'c MODE ! ;

DECIMAL
21 CONSTANT 1SCR
11 CONSTANT 1/2SCR
;
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
       ^M OF  NEWLINE               ENDOF
       BL OF  $$c-l                 ENDOF  ( Cursor right)
      ^ Z OF  PAGE ." VI99 Shell" ABORT ENDOF
      ^ K OF  KILL-BUFFER           ENDOF 
            \ Commands:
              DUP HANDLER
    ENDCASE
  AGAIN ;

\ ======================================
\ ===[ vi style user commands ]===
 VOCABULARY EDITOR
 ONLY FORTH ALSO EDITOR DEFINITIONS

: x   SAVE  uLINE CURSOR CR ABORT ;
: q   x  ABORT ;

: q!  uLINE CURSOR  CR ." Not saved"   ABORT ;

: w   PARSE-NAME DUP IF  +PATH FILENAME PLACE  THEN SAVE ;

: w!  READONLY OFF w ;

: wq  x q ;

\ 123 G *MUST have space after no.
: G    ( n -- ) 1- TOPLINE ! LIST ;

: 1G     1 G ;
: $      LINES @  G ;

\ ==========================
\ Additional shell commands
\ ==========================
INCLUDE DSK4.VIDIR2
INCLUDE DSK4.VILS-L

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

: cd     PARSE-NAME ?DOT TOUPPER  HOME$ PLACE ;

: ls     dir ;
: //     edit ;
: bye    BYE ;
: cold   COLD ;
: clear  PAGE ;

ONLY FORTH DEFINITIONS
\ console REPL with prompt for vi99
DECIMAL 
: prompt$  CR  HOME$ .$  ." $ " ;

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
  DECIMAL 
  INIT-WORDLISTS
  80COLS  DKGRN/BLK SCREEN
  NEW-CURSORS
  uLINE CURSOR
  ['] NEWQUIT ['] QUIT CELL+ !  \ patch quit (Forth interpreter)

  GETDEV 
  READONLY OFF 

  PAGE ." VI99 Command Shell 1.43 2023 Brian Fox"
  CR
  CR ." Type help to see manpage"
  CR ." Type ls to see files on disk"
  CR ." Type bye    to exit vi99"

  ONLY FORTH ALSO EDITOR DEFINITIONS
  ABORT ;

HERE SWAP - DECIMAL .

 LOCK
 INCLUDE DSK1.SAVESYS
 ' VI99 SAVESYS DSK4.VI9980

NEW-CURSORS
ALSO EDITOR
