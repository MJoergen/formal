MOVE R2, R6    ; Write value 0x0222 to register 6
MOVE R3, @R6   ; Write value 0x0333 to memory 0x0222
MOVE @R6, R4   ; Write value 0x0333 to register 4
MOVE @R6, @R7  ; Write value 0x0333 to memory 0x0777

ADD R2, R9     ; Write value 0x0BBB to register 9
ADD R3, @R9    ; Write value 0x0333 to memory 0x0BBB
ADD @R9, R8    ; Write value 0x0BBB to register 8
ADD @R8, @R7   ; Write value 0x0666 to memory 0x0777

CMP R2, R8
CMP R3, @R8
CMP @R4, R8
CMP @R5, @R8

HALT

