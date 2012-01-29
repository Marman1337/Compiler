%{
#include <iostream>
#include "yacc.tab.h"
using namespace std;

int yylex();
extern void yyerror(char *);
%}
%token PROGRAM IDENTIFIER SEMICOLON VAR COLON COMMA INT SHORTINT LONGINT BOOLEAN BEGINN END IF THEN ELSE BYTE CHAR NUMBER MATHOP OBRACE CBRACE EQUALOP ASSIGNOP

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
		| BOOLEAN;

%%
int main()
{
	yyparse();
}

void yyerror(char *s)
{
	cout << "error" << endl;
}
