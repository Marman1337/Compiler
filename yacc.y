%{
#include <iostream>
#include "yacc.tab.h"
using namespace std;

int yylex();
void yyerror(char const *);
extern int lineno;
%}

%token PBEGIN END PROGRAM IF THEN ELSE VAR INT
PLUS MINUS MUL DIV LT GT LE GE NE
OPAREN CPAREN SEMICOLON COLON COMMA EQUALOP ASSIGNOP DOT

%union
{
	int ival;
	char *sval;
}
%token <ival> NUMBER
%token <sval> IDENTIFIER

%%

program			: /* empty program */
			| program_header var_declarations block DOT {cout << "\nEND\n";}

program_header		: PROGRAM IDENTIFIER SEMICOLON {cout << "AREA " << $2 << ",CODE,READWRITE\n\nENTRY\n\n"; delete $2};

var_declarations	: VAR var_list;

var_list		: var_identifiers COLON var_type SEMICOLON;

var_identifiers		: IDENTIFIER
			| var_identifiers COMMA IDENTIFIER;

var_type		: INT;

block			: PBEGIN statement_list END;

statement_list		: statement_list statement
			| statement;

statement		: assignment_statement SEMICOLON;

assignment_statement	: IDENTIFIER ASSIGNOP expression;

expression		: expression addop term
			| term;

term			: NUMBER
			| IDENTIFIER;

addop			: PLUS
			| MINUS;

%%
int main()
{
	yyparse();
}

void yyerror(char const *s)
{
	cout << "Error: " << s << ", line: " << lineno << endl;
}
