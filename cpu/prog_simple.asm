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

      MOVE L_4, R13     ; Initialize stack pointer
      RSUB L_3, 1

      MOVE 0x1234, R1   ; Write value 0x1234 to register 1
      ADD  0x2345, R1   ; Write value 0x3579 to register 1

      CMP  0x1234, R1
      CMP  R1, 0x2345

      CMP  0x1234, @R1
      CMP  @R1, 0x2345

      ABRA L_1, 1
      HALT

L_1   RBRA L_2, 1
      HALT

L_2   HALT

L_3   MOVE    @R13++, R15
      .DW 0x0000
      .DW 0x0000
      .DW 0x0000
      .DW 0x0000
L_4
