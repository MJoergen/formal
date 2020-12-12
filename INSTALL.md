# Installing tools for formal verification

Getting formal verification to work in VHDL requires quite a lot of manual
setup and install; it would seem the tools are not quite as mature for VHDL.
Anyway, I managed to get it working in the end.

In order to use formal verification of VHDL, you need to install a bunch of tools:
* Yosys, SymbiYosys, and some SAT solvers
* GNAT, GHDL, and the ghdl-yosys-plugin

## Install Yosys, SymbiYosys, and some SAT solvers
This is described in detail in [this link](https://symbiyosys.readthedocs.io/en/latest/install.html).

Note that on my machine (running Linux Mint 19.3 with GCC 9.3) I ran into
the following error when building the Avy project:

```
extavy/avy/src/ItpMinisat.h:127:52: error: cannot convert ‘boost::logic::tribool’ to ‘bool’ in return
  127 |     bool isSolved () { return m_Trivial || m_State || !m_State; }
      |                               ~~~~~~~~~~~~~~~~~~~~~^~~~~~~~~~~
      |                                                    |
      |                                                    boost::logic::tribool
```

I fixed this by applying the following patch:

```
extavy/avy ((0db110e...)) $ git diff
diff --git a/src/ItpGlucose.h b/src/ItpGlucose.h
index 657253d..4ffe55f 100644
--- a/src/ItpGlucose.h
+++ b/src/ItpGlucose.h
@@ -126,7 +126,7 @@ namespace avy
     ::Glucose::Solver* get () { return m_pSat; }

     /// true if the context is decided
-    bool isSolved () { return m_Trivial || m_State || !m_State; }
+    bool isSolved () { return bool{m_Trivial || m_State || !m_State}; }

     int core (int **out)
     {
@@ -182,7 +182,7 @@ namespace avy
     bool getVarVal(int v)
     {
         ::Glucose::Var x = v;
-        return tobool (m_pSat->modelValue(x));
+        return bool{tobool (m_pSat->modelValue(x))};
     }
   };

diff --git a/src/ItpMinisat.h b/src/ItpMinisat.h
index d145d7c..7514f31 100644
--- a/src/ItpMinisat.h
+++ b/src/ItpMinisat.h
@@ -124,7 +124,7 @@ namespace avy
     ::Minisat::Solver* get () { return m_pSat.get (); }

     /// true if the context is decided
-    bool isSolved () { return m_Trivial || m_State || !m_State; }
+    bool isSolved () { return bool{m_Trivial || m_State || !m_State}; }

     int core (int **out)
     {
```


## Install GNAT, GHDL, and the ghdl-yosys-plugin

The details are described [here](https://github.com/ghdl/ghdl-yosys-plugin).

