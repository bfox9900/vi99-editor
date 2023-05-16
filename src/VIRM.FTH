\ rm.fth  delete a DV80 file for VI99 Shell 

: SURE?  ( -- ?)
    CR ." Are you sure? (Y/N)" 
    KEY TOUPPER [CHAR] Y =   
;

: (RM)  ( addr len )
    TOUPPER +PATH ( PAD len ) 
    DV80 R/W OPEN-FILE ?FILERR
    CR CR ." Delete " PAD COUNT TYPE
    SURE?
    IF  7 FILEOP ?FILERR
        CLOSE-FILE 2DROP
        CR ." Done"
    ELSE
        DROP CR ." Cancelled" CR
    THEN ;

: rm  PARSE-NAME  (RM) ;
