DECIMAL 

\ 1 tick = 21.3 uS 
: .uS  ( ticks  -- uS )   213 10 */  . ." uS" ;

HEX 
: TEST 
     A000 1000 C00 VWRITE
;
DECIMAL 