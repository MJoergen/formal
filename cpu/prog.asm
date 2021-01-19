MOVE R2, R6    ; Write value 0x0222 to register 6
MOVE R3, @R6   ; Write value 0x0333 to memory 0x0222
MOVE @R6, R4   ; Write value 0x0333 to register 4
MOVE @R6, @R7  ; Write value 0x0333 to memory 0x0777

ADD R2, R6
ADD R3, @R6
ADD @R4, R6
ADD @R5, @R6

CMP R2, R6
CMP R3, @R6
CMP @R4, R6
CMP @R5, @R6

HALT

