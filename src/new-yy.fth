
: $$c-y  \ vi copy command 
  CMDKEY [CHAR] y <> IF END
  SAVE-XY
  ELINE# GOTOLN  
  ELINE$ 
  ARG# 0 
  ?DO 
     DUP COUNT V$PUSH  \ push from HEAP to linestack 
     NEXT$ 
  LOOP 
  DROP 
  REST-XY ; 