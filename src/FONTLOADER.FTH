\ vi99 font loader
HEX
0D CONSTANT R/O100  \ READ ONLY,  binary, relative, fixed 100

: NEWPAB   (  file$ len VDPaddr #bytes mode -- )
  -30 ^PAB +!         \ create small pab in VDP RAM
  [PAB 30 0 VFILL     \ erase PAB and file name
  0 [PAB RECLEN] VC!  \ set reclen (0 means >100 (256) bytes)
\ pulls params from the stack to init the PAB
  [PAB FLG] VC!       \ set file access mode byte
  [PAB REC#]  V!      \ set #bytes to save (integer)
  [PAB FBUFF] V!      \ set where the file will load VDP Ram
  [PAB FNAME] VPLACE  \ set file name
;

: POPPAB  ( -- ) 30 ^PAB +! ;

: LOAD-FILE ( file$ len VDPaddr size mode -- ior)
  NEWPAB  5 FILEOP  POPPAB ;
\                               pdt size  mode
: LOAD-FONT ( file$ len -- ?) 800 1000  R/O100 LOAD-FILE ;
DECIMAL 
