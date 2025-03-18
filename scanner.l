%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "parser.h"

/*
 * Set up a simplified stack to track indentation level as described in the
 * Python docs.  Put 0 on top of the stack.
 *
 * https://docs.python.org/3/reference/lexical_analysis.html#indentation
 */
#define MAX_INDENT_LEVELS 128
static int _indent_stack[MAX_INDENT_LEVELS] = { 0 };
static int _indent_stack_top = 0;
void indent_stack_push(int);
void indent_stack_pop();
int indent_stack_top();
int indent_stack_isempty();

static YYSTYPE yylval;
static YYLTYPE yylloc;

extern yypstate* pstate;

#define PUSH_TOKEN(category) do {                               \
    int s = yypush_parse(pstate, category, &yylval, &yylloc);   \
    if (s != YYPUSH_MORE) {                                     \
        yypstate_delete(pstate);                                \
        return s;                                               \
    }                                                           \
} while (0)

#define YY_USER_ACTION \
    yylloc.first_line = yylloc.last_line = yylineno; 
%}

%option noyywrap
%option yylineno

%%

^[ \t]*\r?\n  /* Skip blank lines */

^[ \t]*#.*\r?\n  /* Skip whole-line comments. */

#.*$  /* Skip comments on the same line as a statement. */

^[ \t]+ {
    /*
     * Handle indentation as described in Python docs linked above. Note that
     * this rule's pattern treats leading spaces and leading tabs equivalently,
     * which could cause some unexpected behavior (compared to normal Python
     * indentation behavior) if they're combined in a single line.  For the
     * purposes of this project, that's OK.
     */
    if (indent_stack_top() < yyleng) {
        /*
         * If the current indentation level is greater than the previous indentation
         * level (stored at the top of the stack), then emit an INDENT and push the
         * new indentation level onto the stack.
         */
        //printf("INDENT\n");
        yylval.str = malloc(yyleng + 1);
        strncpy(yylval.str, yytext, yyleng + 1);
        PUSH_TOKEN(INDENT);
        indent_stack_push(yyleng);
    } else {
        /*
         * If the current indentation level is less than the previous indentation
         * level, pop indentation levels off the stack until the top is equal to
         * the current indentation level.  Emit a DEDENT for each element popped
         * from the stack.
         */
        while (!indent_stack_isempty() && indent_stack_top() != yyleng) {
            indent_stack_pop();
            PUSH_TOKEN(DEDENT);
            //printf("DEDENT\n");
        }

        /*
         * If we popped everything off the stack, that means the current
         * indentation level didn't match any on the stack, which is an indentation
         * error.
         */
        if (indent_stack_isempty()) {
            fprintf(stderr, "Error: Incorrect indentation on line %d\n", yylineno);
            return 1;
        }
    }
}

^[^ \t\r\n]+ {
    /*
     * If we find a line that's not indented (i.e. a line that begins with
     * non-whitespace characters), pop all indentation levels off the stack,
     * and emit a DEDENT for each one.  Then, call REJECT, so the next rule
     * matching this token (i.e. the one at the beginning of the line) is also
     * applied.
     */
    while (indent_stack_top() != 0) {
        indent_stack_pop();
        PUSH_TOKEN(DEDENT);
        //printf("DEDENT\n");
    }
    REJECT;
}

\r?\n {
  /*
   * This rule will apply only to endlines that come after a statement.
   * Endlines associated with empty lines and comments are handled above.
   * This rule handles both Unix-style and Windows-style line endings.
   */
  //printf("NEWLINE\n");
  PUSH_TOKEN(NEWLINE);
}

<<EOF>> {
    /*
     * If we reach the end of the file, pop all indentation levels off the stack
     * and emit a DEDENT for each one.
     */
    while(indent_stack_top() != 0) {
        indent_stack_pop();
        //printf("DEDENT\n");
        PUSH_TOKEN(DEDENT);
    }
    int s = yypush_parse(pstate, 0, NULL, NULL);
    yypstate_delete(pstate);
    return s;
}

[ \t]  /* Ignore spaces that haven't been handled above. */

"and"       {PUSH_TOKEN(AND);}
"break"     {PUSH_TOKEN(BREAK);}
"def"       {PUSH_TOKEN(DEF);}
"elif"      {PUSH_TOKEN(ELIF);}
"else"      {PUSH_TOKEN(ELSE);}
"for"       {PUSH_TOKEN(FOR);}
"if"        {PUSH_TOKEN(IF);}
"not"       {PUSH_TOKEN(NOT);}
"or"        {PUSH_TOKEN(OR);}
"return"    {PUSH_TOKEN(RETURN);}
"while"     {PUSH_TOKEN(WHILE);}
"True"      {PUSH_TOKEN(TRUE);}
"False"     {PUSH_TOKEN(FALSE);}

[a-zA-Z_][a-zA-Z0-9_]* {
    /*
     * This rule handling identifiers must come after all the keyword rules above,
     * since each keyword would otherwise be treated as a valid identifier.
     */
    // yylval.str = malloc((yyleng + 1) * sizeof(char));
    // strncpy(yylval.str, yytext, yyleng + 1);
    yylval.str = malloc(yyleng + 1);
    strncpy(yylval.str, yytext, yyleng + 1);
    PUSH_TOKEN(IDENTIFIER);
    //printf("IDENTIFIER\t%s\n", yytext);
}

[0-9]*"."[0-9]+ {
    // yylval.float_value = atof(yytext);
    yylval.str = malloc(yyleng + 1);
    strncpy(yylval.str, yytext, yyleng + 1);
    PUSH_TOKEN(FLOAT);
    //printf("FLOAT\t\t%f\n", atof(yytext));
    
}

[0-9]+ {
    // yylval.int_value = atoi(yytext);
    yylval.str = malloc(yyleng + 1);
    strncpy(yylval.str, yytext, yyleng + 1);
    PUSH_TOKEN(INTEGER);
    //printf("INTEGER\t\t%d\n", atoi(yytext));
}

"="     {PUSH_TOKEN(ASSIGN);}
"+"     {PUSH_TOKEN(PLUS);}
"-"     {PUSH_TOKEN(MINUS);}
"*"     {PUSH_TOKEN(TIMES);}
"/"     {PUSH_TOKEN(DIVIDEDBY);}
"=="    {PUSH_TOKEN(EQ);}
"!="    {PUSH_TOKEN(NEQ);}
">"     {PUSH_TOKEN(GT);}
">="    {PUSH_TOKEN(GTE);}
"<"     {PUSH_TOKEN(LT);}
"<="    {PUSH_TOKEN(LTE);}
"("     {PUSH_TOKEN(LPAREN);}
")"     {PUSH_TOKEN(RPAREN);}
","     {PUSH_TOKEN(COMMA);}
":"     {PUSH_TOKEN(COLON);}

. {
    fprintf(stderr, "Invalid symbol on line %d: %s\n", yylineno, yytext);
    return 1;
}

%%

/*
 * This function pushes another level to the indentation stack.
 */
void indent_stack_push(int l) {
    /*
     * Increment index of top and make sure it's still within the bounds of the
     * stack array.  If it isn't exit with an error.
     */
    _indent_stack_top++;
    if (_indent_stack_top >= MAX_INDENT_LEVELS) {
        fprintf(stderr, "ERROR: too many levels of indentation\n");
        exit(1);
    }
    _indent_stack[_indent_stack_top] = l;
}

/*
 * This function pops the top from the indent stack.
 */
void indent_stack_pop() {
    if (indent_stack_top >= 0) {
        _indent_stack_top--;
    }
}

/*
 * This function returns the top of the indent stack.  Returns -1 if the
 * indent stack is empty.
 */
int indent_stack_top() {
    return _indent_stack_top >= 0 ? _indent_stack[_indent_stack_top] : -1;
}

/*
 * This function returns 1 if the indent stack is empty or 0 otherwise.
 */
int indent_stack_isempty() {
    return _indent_stack_top < 0;
}
