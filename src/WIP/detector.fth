\ non-ascii detection: make all non-ascii chars a block character
INCLUDE DSK1.LOADSAVE 
HEX 
: FILL-FONT  800 1000 FF VFILL ;
: DETECTOR    FILL-FONT   S" DSK1.FONT0230"  LOAD-FONT ;
DECIMAL 
