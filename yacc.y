%{
#include <iostream>
#include "yacc.tab.h"
using namespace std;

int yylex();
extern void yyerror(char const *);
%}
%token PROGRAM IDENTIFIER VAR
SEMICOLON COLON COMMA
INT SHORTINT LONGINT BOOLEAN BYTE CHAR
BEGINN END
IF THEN ELSE
NUMBER MATHOP
OBRACE CBRACE
EQUALOP ASSIGNOP

%%

program		: /* empty program */
		| header variables;

header		: PROGRAM IDENTIFIER SEMICOLON;

variables	: VAR var_identifiers COLON var_type SEMICOLON;

var_identifiers	: IDENTIFIER
		| var_identifiers COMMA IDENTIFIER;

var_type	: INT
		| SHORTINT
		| LONGINT
		| BOOLEAN
		| BYTE
		| CHAR;

%%
int main()
{
	yyparse();
}

void yyerror(char const *s)
{
	cout << "error" << endl;
}
