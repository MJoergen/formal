# A new implemenation of the QNICE CPU

## TODO
Two optimizations:
1. Let the FETCH module present two (or three) words to the DECODE module, so the latter doesn't have to wait.
2. Eliminate the NOP cycle from the CMP @R1, @PC++ instruction.

## Block diagram
![Block Diagram](cpu.png)

## Synthesis
```
Number of cells:               5813
  $assert                         1
  BUFG                            1
  CARRY4                         36
  FDRE                          358
  FDSE                            2
  IBUF                            2
  INV                            96
  LUT1                           69
  LUT2                          243
  LUT3                          245
  LUT4                          220
  LUT5                          557
  LUT6                         1226
  MUXF7                        1024
  MUXF8                         173
  OBUF                           16
  RAM128X1D                    1024
  RAM32M                          8
  RAM64M                        512

Estimated number of LCs:       2248
```

