%{
#include <iostream>
#include "yacc.tab.h"
using namespace std;

int yylex();
void yyerror(char const *);
extern int lineno;
%}

%token PBEGIN END PROGRAM IF THEN ELSE VAR SHORTINT INT LONGINT BYTE
BOOLEAN CHAR IDENTIFIER NUMBER PLUS MINUS MUL DIV OBRACE CBRACE
SEMICOLON COLON COMMA EQUALOP ASSIGNOP DOT

%%

program		: /* empty program */
		| header variables PBEGIN END DOT;

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
	cout << "error " << lineno << endl;
}
