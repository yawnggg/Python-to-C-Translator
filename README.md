# Python-to-C Translator

A Python-to-C code translator that converts a subset of Python into equivalent C code. It implements a custom scanner (lexer) and a custom parser using Flex (Lex) and Bison (Yacc). The program tokenizes and parses Python syntax, generates corresponding C code, and manages a symbol table to track variable declarations and values.

Unlike traditional compilers that construct an Abstract Syntax Tree (AST), this translator directly generates C code using string manipulation during parsing.


# How It Works

1. Lexical Analysis (Scanning)  
  •  The Flex scanner tokenizes Python code into keywords, identifiers, operators, and numbers  
  •  It also implements a stack-based system to manage Python-style indentation and translate it into C-style {} blocks  
3. Syntax Analysis (Parsing)  
  •  The Bison parser applies Python grammar rules and translates statements into C syntax  
  •  It handles assignments, arithmetic expressions, conditionals (if), and loops (while)  
4. Symbol Table Management  
  •  Tracks variable declarations and stores values to ensure proper C code generation  
  •  Detects undefined identifiers and reports errors  
5. C Code Generation  
  •  Produces a C main() function with:  
    -  Variable declarations based on the symbol table  
    -  C-equivalent statements for assignments, conditionals, and loops  
    -  Formatted print statements to output variable values  


# Installation & Usage

  •  Before compiling, ensure you have the following installed:
  
      -  bison (for parsing)  
      -  flex (for lexical analysis)  
      -  gcc (for compiling)  
      -  make (for building)  
      
  •  For Debian/Ubuntu run: 
  
      sudo apt install bison flex make gcc
  •  For macOS (using Homebrew) run: 
  
      brew install bison flex make gcc
  •  For Windows (using MSYS2) run: 
  
      pacman -S --needed mingw-w64-x86_64-bison mingw-w64-x86_64-flex mingw-w64-x86_64-gcc make

  •  To compile the translator, run:
  
      make

  •  To translate a Python file into C, use:
  
      ./parse < testing_code/p1.py
      ./parse < testing_code/p2.py
      ./parse < testing_code/p3.py
      ./parse < testing_code/p4.py

  •  The translator detects syntax errors in Python files. Try running:
  
      ./parse < testing_code/error1.py
      ./parse < testing_code/error2.py
      ./parse < testing_code/error3.py
      ./parse < testing_code/error4.py


# Tools and Technologies

  •  C  
  •  Flex  
  •  Bison  
