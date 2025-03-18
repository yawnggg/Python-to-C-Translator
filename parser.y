%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "parser.h"

char identifiers[100][100];
float values[100];
int symbol_count = 0;
char* program = NULL;
int _error = 0;

void yyerror(YYLTYPE* loc, const char* err);    // Location is passed into yyerror when it is called
int find_symbol(const char* identifier);
void insert_symbol(const char* identifier, float value);
void print_symbol_table();
void print_program();
void print_variable_values();

yypstate* pstate;
extern int yylex();
%}

// Settings for implementing a push parser
%define api.push-pull push  // Giving the parser a signal that is a push parser instead of a pull parser
%define api.pure full   // Telling the parser to stop relying on global variables to communicate with the scanner, and instead use function arguments to pass values into the parser

%locations
%define parse.error verbose

%union {
  char* str;
} 

%token <str> IDENTIFIER
%token <str> FLOAT
%token <str> INTEGER
%token <str> TRUE FALSE
%token <str> BREAK ELIF ELSE IF NOT WHILE AND DEF FOR OR
%token <str> ASSIGN PLUS MINUS TIMES DIVIDEDBY EQ NEQ GT GTE LT LTE
%token <str> LPAREN RPAREN COLON COMMA RETURN
%token <str> INDENT DEDENT
%token <str> NEWLINE

%type <str> program statement assignmentStatement expression single_if multiple_elif single_elif single_else ifStatement whileStatement

%left PLUS MINUS  // Left associative operators with the same precendence
%left TIMES DIVIDEDBY // Indicating that TIMES AND DIVIDEDBY are of higher precendence than PLUS and MINUS
%left LT LTE GT GTE
%left EQ NEQ

%right NOT

%start program

%%

program
  : program statement {
    if ($1 == NULL) {
      int result_length = strlen($2) + 1;
      char* result = malloc(result_length);
      if (!result) {
        fprintf(stderr, "Memory allocation failed\n");
        exit(1);
      }
      sprintf(result, "%s", $2);
      $$ = result;
    } else {
      int result_length = strlen($1) + strlen($2) + 2;
      $$ = realloc($1, result_length);
      if (!$$) {
        fprintf(stderr, "Memory allocation failed\n");
        exit(1);
      }
      strcat($$, "\n");
      strcat($$, $2);

      free($2);
    }
    program = $$;
  }
  | statement {
    int result_length = strlen($1) + 1;
    char* result = malloc(result_length);
    if (!result) {
      fprintf(stderr, "Memory allocation failed\n");
      exit(1);
    }
    sprintf(result, "%s", $1);
    $$ = result;
    program = $$;
  }
  ;

statement
  : assignmentStatement { $$ = $1; }
  | ifStatement { $$ = $1; }
  | whileStatement { $$ = $1; }
  | BREAK NEWLINE {
    int result_length = 7;
    char* result = malloc(result_length);
    if (!result) {
      fprintf(stderr, "Memory allocation failed\n");
      exit(1);
    }
    // Building the break statement string
    sprintf(result, "break;");
    $$ = result;  // Assigning the result to be used by the rest of the parser
  }
  | error NEWLINE {
    fprintf(stderr, "Error: bad statement on line %d\n", @1.first_line);
    _error = 1;
  }
  ;

assignmentStatement
  : IDENTIFIER ASSIGN expression NEWLINE {
    int result_length = strlen($1) + strlen ($3) + 5; // We add 5 for ";", " = ", and "\0"
    char* result = malloc(result_length);
    if (!result) {
      fprintf(stderr, "Memory allocation failed\n");
      exit(1);
    }
    // Building the assignment statement string
    sprintf(result, "%s = %s;", $1, $3);
    //printf("%s\n", result);
    insert_symbol($1, atof($3));
    free($1);
    free($3);
    $$ = result;  // Assigning the result to be used by the rest of the parser
  }
  ;

ifStatement
  : single_if { $$ = $1; }
  | single_if multiple_elif { 
    int result_length = strlen($1) + strlen($2) + 2; 
    char* result = malloc(result_length);
    if (!result) {
      fprintf(stderr, "Memory allocation failed\n");
      exit(1);
    }
    // Building the multiple elif statement string
    sprintf(result, "%s %s", $1, $2);
    $$ = result;  // Assigning the result to be used by the rest of the parser
  }
  | single_if single_else {
    int result_length = strlen($1) + strlen($2) + 2; 
    char* result = malloc(result_length);
    if (!result) {
      fprintf(stderr, "Memory allocation failed\n");
      exit(1);
    }
    // Building the else statement string
    sprintf(result, "%s %s", $1, $2);
    $$ = result;  // Assigning the result to be used by the rest of the parser
  }
  | single_if multiple_elif single_else {
    int result_length = strlen($1) + strlen($2) + strlen($3) + 2; 
    char* result = malloc(result_length);
    if (!result) {
      fprintf(stderr, "Memory allocation failed\n");
      exit(1);
    }
    // Building the multiple elif and else statement string
    sprintf(result, "%s %s %s", $1, $2, $3);
    $$ = result;  // Assigning the result to be used by the rest of the parser
  }
  ;

multiple_elif
  : single_elif { $$ = $1; }
  | multiple_elif single_elif {
    int result_length = strlen($1) + strlen($2) + 2; 
    char* result = malloc(result_length);
    if (!result) {
      fprintf(stderr, "Memory allocation failed\n");
      exit(1);
    }
    // Building the multiple elif statement string
    sprintf(result, "%s %s", $1, $2);
    $$ = result;  // Assigning the result to be used by the rest of the parser
  }
  ;

single_if
  : IF expression COLON NEWLINE INDENT program DEDENT {
    int result_length = strlen($2) + strlen($6) + 11; // We add 10 for the spaces, the "if", the "else", and the "\0"
    char* result = malloc(result_length);
    if (!result) {
      fprintf(stderr, "Memory allocation failed\n");
      exit(1);
    }
    // Building the if statement string
    sprintf(result, "if (%s) {\n%s\n}", $2, $6);
    $$ = result;  // Assigning the result to be used by the rest of the parser
  }
  ;

single_elif:
  ELIF expression COLON NEWLINE INDENT program DEDENT {
    int result_length = strlen($2) + strlen($5) + 16; 
    char* result = malloc(result_length);
    if (!result) {
      fprintf(stderr, "Memory allocation failed\n");
      exit(1);
    }
    // Building the elif statement string
    sprintf(result, "else if (%s) {\n%s\n}", $2, $6);
    $$ = result;  // Assigning the result to be used by the rest of the parser
  }
  ;

single_else
  : ELSE COLON NEWLINE INDENT program DEDENT {
    int result_length = strlen($5) + 10; 
    char* result = malloc(result_length);
    if (!result) {
      fprintf(stderr, "Memory allocation failed\n");
      exit(1);
    }
    // Building the else statement string
    sprintf(result, "else {\n%s\n}", $5);
    $$ = result;  // Assigning the result to be used by the rest of the parser
  }
  ;


whileStatement
  : WHILE expression COLON NEWLINE INDENT program DEDENT {
    int result_length = strlen($2) + strlen($6) + 11; 
    char* result = malloc(result_length);
    if (!result) {
      fprintf(stderr, "Memory allocation failed\n");
      exit(1);
    }
    // Building the while statement string
    sprintf(result, "while (%s) {\n%s\n}", $2, $6);
    $$ = result;  // Assigning the result to be used by the rest of the parser
  }
  ;

expression 
  : LPAREN expression RPAREN { 
    int result_length = strlen($2) + 2; // We add 3 for the parenthesis
    char* result = malloc(result_length);
    if (!result) {
      fprintf(stderr, "Memory allocation failed\n");
      exit(1);
    }
    // Building the expression string
    sprintf(result, "(%s)", $2);
    $$ = result;  // Assigning the result to be used by the rest of the parser
   }
  | expression PLUS expression {
    int result_length = strlen($1) + strlen($3) + 3; // We add 3 for the spaces and the operator
    char* result = malloc(result_length);
    if (!result) {
      fprintf(stderr, "Memory allocation failed\n");
      exit(1);
    }
    // Building the expression string
    sprintf(result, "%s + %s", $1, $3);
    $$ = result;  // Assigning the result to be used by the rest of the parser
  }
  | expression TIMES expression {
    int result_length = strlen($1) + strlen($3) + 3; // We add 3 for the spaces and the operator
    char* result = malloc(result_length);
    if (!result) {
      fprintf(stderr, "Memory allocation failed\n");
      exit(1);
    }
    // Building the expression string
    sprintf(result, "%s * %s", $1, $3);
    $$ = result;  // Assigning the result to be used by the rest of the parser
  }
  | expression MINUS expression {
    int result_length = strlen($1) + strlen($3) + 3; // We add 3 for the spaces and the operator
    char* result = malloc(result_length);
    if (!result) {
      fprintf(stderr, "Memory allocation failed\n");
      exit(1);
    }
    // Building the expression string
    sprintf(result, "%s - %s", $1, $3);
    $$ = result;  // Assigning the result to be used by the rest of the parser
  }
  | expression DIVIDEDBY expression {
    int result_length = strlen($1) + strlen($3) + 3; 
    char* result = malloc(result_length);
    if (!result) {
      fprintf(stderr, "Memory allocation failed\n");
      exit(1);
    }
    // Building the expression string
    sprintf(result, "%s / %s", $1, $3);
    $$ = result;  // Assigning the result to be used by the rest of the parser
  }
  | expression EQ expression {
    int result_length = strlen($1) + strlen($3) + 3; 
    char* result = malloc(result_length);
    if (!result) {
      fprintf(stderr, "Memory allocation failed\n");
      exit(1);
    }
    // Building the expression string
    sprintf(result, "%s == %s", $1, $3);
    $$ = result;  // Assigning the result to be used by the rest of the parser
  }
  | expression NEQ expression {
    int result_length = strlen($1) + strlen($3) + 3; 
    char* result = malloc(result_length);
    if (!result) {
      fprintf(stderr, "Memory allocation failed\n");
      exit(1);
    }
    // Building the expression string
    sprintf(result, "%s != %s", $1, $3);
    $$ = result;  // Assigning the result to be used by the rest of the parser
  }
  | expression LT expression {
    int result_length = strlen($1) + strlen($3) + 3; 
    char* result = malloc(result_length);
    if (!result) {
      fprintf(stderr, "Memory allocation failed\n");
      exit(1);
    }
    // Building the expression string
    sprintf(result, "%s < %s", $1, $3);
    $$ = result;  // Assigning the result to be used by the rest of the parser
  }
  | expression LTE expression {
    int result_length = strlen($1) + strlen($3) + 3; 
    char* result = malloc(result_length);
    if (!result) {
      fprintf(stderr, "Memory allocation failed\n");
      exit(1);
    }
    // Building the expression string
    sprintf(result, "%s <= %s", $1, $3);
    $$ = result;  // Assigning the result to be used by the rest of the parser
  }
  | expression GT expression {
    int result_length = strlen($1) + strlen($3) + 3; 
    char* result = malloc(result_length);
    if (!result) {
      fprintf(stderr, "Memory allocation failed\n");
      exit(1);
    }
    // Building the expression string
    sprintf(result, "%s > %s", $1, $3);
    $$ = result;  // Assigning the result to be used by the rest of the parser
  }
  | expression GTE expression {
    int result_length = strlen($1) + strlen($3) + 3; 
    char* result = malloc(result_length);
    if (!result) {
      fprintf(stderr, "Memory allocation failed\n");
      exit(1);
    }
    // Building the expression string
    sprintf(result, "%s >= %s", $1, $3);
    $$ = result;  // Assigning the result to be used by the rest of the parser
  }
  | NOT expression {
    int result_length = strlen($2) + 2; // We add 2 for the "!" and the "\0"
    char* result = malloc(result_length);
    if (!result) {
      fprintf(stderr, "Memory allocation failed\n");
      exit(1);
    }
    // Building the expression string
    sprintf(result, "!%s", $2);
    $$ = result;  // Assigning the result to be used by the rest of the parser
  }
  | FLOAT { $$ = $1; }
  | INTEGER { $$ = $1; }
  | IDENTIFIER { 
    int symbol_index = find_symbol($1);
    if (symbol_index != -1) {
      int result_length = strlen($1) + 1;
      char* result = malloc(result_length);
      if (!result) {
        fprintf(stderr, "Memory allocation failed\n");
        exit(1);
      }
      sprintf(result, "%s", $1);  // Duplicate the string
      $$ = result;
    } else {
      fprintf(stderr, "Error: unknown symbol (%s) on line %d\n", $1, @1.first_line);
      _error = 1;
      YYERROR;
    }
    free($1); // Free the dynamically allocated memory for $1
  }
  | TRUE { 
    int result_length = 2;
    char* result = malloc(result_length);
    if (!result) {
      fprintf(stderr, "Memory allocation failed\n");
      exit(1);
    }
    // Building the expression string
    sprintf(result, "1");
    $$ = result;  // Assigning the result to be used by the rest of the parser
  }
  | FALSE { 
    int result_length = 2;
    char* result = malloc(result_length);
    if (!result) {
      fprintf(stderr, "Memory allocation failed\n");
      exit(1);
    }
    // Building the expression string
    sprintf(result, "0");
    $$ = result;  // Assigning the result to be used by the rest of the parser
  }
  ;

%%

void yyerror(YYLTYPE* loc, const char* err) {
  if(_error == 0) {
    fprintf(stderr, "Error at line %d: %s\n", loc->first_line, err);
    _error = 1;
  }
}

int find_symbol(const char* identifier) { // Function to find the index of a symbol in the symbol table
  for (int i = 0; i < symbol_count; ++i) {  
    if (strcmp(identifiers[i], identifier) == 0) {
      return i;
    }
  }
  return -1; // If identifier is not found, return -1
}

void insert_symbol(const char* identifier, float value) {
  int index = find_symbol(identifier);  // Calling find_symbol to check if the identifier is already in the symbol table
  if (index != -1) {  // If the identifier is found (already exists in the symbol table)...
    values[index] = value;   
  } else {
    if (symbol_count < 100) {
      strncpy(identifiers[symbol_count], identifier, 100 - 1);
      identifiers[symbol_count][100 - 1] = '\0';
      values[symbol_count] = value;
      symbol_count++;
    } else {
      fprintf(stderr, "Symbol table full, cannot insert new symbol.\n");
    }
  }
}

void print_symbol_table() {
  for (int i = 0; i < symbol_count; ++i) {
    printf("float %s;\n", identifiers[i]);
  }
}

void print_program() {
  if (program) {
    printf("%s\n", program);
  }
}

void print_variable_values() {
  for (int i = 0; i < symbol_count; ++i) {
    printf("printf(\"%s: %%f\\n\", %s);\n", identifiers[i], identifiers[i]);
  }
}

int main(int argc, char const *argv[]) {
  
  pstate = yypstate_new();  // Initialize parser state

  while (1) {
    int token = yylex();
    if (token == 0 || _error) {
      break;
    }
  }

  if (_error == 0) {  // If no errors were found during parsing...
    // Print the boilerplate C program
    printf("#include <stdio.h>\n");
    printf("int main() {\n");

    // Print the symbol table as variable declarations
    print_symbol_table();

    // Print the translated program
    printf("\n/* Begin Program */\n\n");

    print_program();

    printf("\n/* End Program */\n\n");

    // Print code to output the values of the variables
    print_variable_values();

    printf("}\n");

    // Free allocated memory for program
    if (program) {
      free(program);
    }

    //yypstate_delete(pstate);  // Clean up parser state

    return 0;
  } else {
    printf("ERROR\n");
    //yypstate_delete(pstate);  // Clean up parser state
    return 1;
  }
}

