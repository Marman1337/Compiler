%{
#include <iostream>
#include "yacc.tab.h"
using namespace std;

int yylex();
void yyerror(char const *);
extern int lineno;

char* variables[10];
int var_index = 0;
%}

%token PBEGIN END PROGRAM IF THEN ELSE VAR SHORTINT INT LONGINT BYTE
BOOLEAN CHAR PLUS MINUS MUL DIV OBRACE CBRACE
SEMICOLON COLON COMMA EQUALOP ASSIGNOP DOT

%union
{
	int ival;
	char *sval;
}
%token <ival> NUMBER
%token <sval> IDENTIFIER

%%

program			: /* empty program */
			| program_header var_declarations block DOT;

program_header		: PROGRAM IDENTIFIER SEMICOLON {cout << "Nazwa programu: " << $2 << endl; delete $2};

var_declarations	: VAR var_list {cout << "Zadeklarowane zmienne: "; for(int i = 0; i < var_index; i++) cout << variables[i] << " "; cout << endl;};

var_list		: var_list single_var_list
			| single_var_list;

single_var_list		: var_identifiers COLON var_type SEMICOLON;

var_identifiers		: IDENTIFIER {variables[var_index] = $1; var_index++;}
			| var_identifiers COMMA IDENTIFIER {variables[var_index] = $3; var_index++;};

var_type		: INT
			| SHORTINT
			| LONGINT
			| BOOLEAN
			| BYTE
			| CHAR;

block			: PBEGIN statement_list END;

statement_list		: statement_list statement
			| statement;

statement		: assignment_statement SEMICOLON;

assignment_statement	: IDENTIFIER ASSIGNOP expression;

expression		: expression addop term
			| term;

term			: NUMBER;

addop			: PLUS
			| MINUS;

%%
int main()
{
	yyparse();
}

void yyerror(char const *s)
{
	cout << "error " << lineno << endl;
}
