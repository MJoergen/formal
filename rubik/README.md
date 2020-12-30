# Rubik's 2x2x2 cube solver

This is another fun application of the formal verification tools;
used here to solve the Rubik's 2x2x2 cube.

## Implementation
The cube has six faces each with four colors, i.e.  a total of 24 tiles.  Each
color is selected from a palette of six possible colors.  So I've chosen a
simple representation, where I assign each of the 24 tiles a 3-bit value for
the color.

The faces are called `U` (Up), `F` (Front), `R` (Right), `D` (Down), `B`
(Back), and `L` (Left), and the state of the cube is represented by
these signals:

```
signal u0 : std_logic_vector(2 downto 0) := "000";
signal u1 : std_logic_vector(2 downto 0) := "000";
signal u2 : std_logic_vector(2 downto 0) := "000";
signal u3 : std_logic_vector(2 downto 0) := "000";

signal f0 : std_logic_vector(2 downto 0) := "001";
signal f1 : std_logic_vector(2 downto 0) := "001";
signal f2 : std_logic_vector(2 downto 0) := "001";
signal f3 : std_logic_vector(2 downto 0) := "001";

etc.
```

The tiles are numbered as follows:
```
        U0 U1
        U2 U3
        -----
L0 L1 | F0 F1 | R0 R1 | B0 B1
L2 L3 | F2 F3 | R2 R3 | B2 B3
        -----
        D0 D1
        D2 D3
```

I've chosen to keep the action on the cube simple. Since the cube is only
2x2x2, I can limit the possible rotations to only the `U`, `F`, and `R` sides.
So a total of nine possible commands:

* `C_CMD_FP = F+`
* `C_CMD_F2 = F2`
* `C_CMD_FM = F-`
* `C_CMD_RP = R+`
* `C_CMD_R2 = R2`
* `C_CMD_RM = R-`
* `C_CMD_UP = U+`
* `C_CMD_U2 = U2`
* `C_CMD_UM = U-`

The interface to [the module](rubik.vhd) is very simple:

```
cmd_i  : in  std_logic_vector(3 downto 0);
done_o : out std_logic
```

The combinatorial signal `done_o` is asserted when the cube is solved.

## Simulation (manual testbench)
For the sake of generating a suitable problem for the solver, I've implemented
a [regular testbench](rubik_tb.vhd).

This testbench has two purposes. First it verifies the period of each of the
nine possible rotations. So for instance, the rotation `F+` has a period of 4.
This means that repeating the rotation four times should leave cube unchanged.
This is a manual test (i.e not using formal verification) to clear out some of
the typing mistakes in the implementation.

The second part of the testbench generates a sequence of random commands,
starting from the solved cube. I then manually record the outcome.

