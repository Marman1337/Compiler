%{
#include <iostream>
#include <string>
#include <iomanip>
#include "yacc.tab.h"
#include "var_table.h"
using namespace std;

int yylex();
void yyerror(char const *);
extern int lineno;
Var_table var_table;
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

var_identifiers		: IDENTIFIER {var_table.addVariable($1); delete $1}
			| var_identifiers COMMA IDENTIFIER {var_table.addVariable($3); delete $3};

var_type		: INT;

block			: PBEGIN statement_list END;

statement_list		: statement_list statement
			| statement;

statement		: assignment_statement SEMICOLON;

assignment_statement	: IDENTIFIER ASSIGNOP expression
			{
				var_entry *temp = var_table.lookup($1);
				if(temp != NULL)
					temp->initialised = true;
				else
				{
					string temp("Undeclared variable '");
					temp.append($1); temp.append("'");
					yyerror(temp.c_str());
				}
				delete $1;
			}; 

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
	//for(int i = 0; i < var_table.table.size(); i++)
	//	cout << "Variable: " << var_table.table[i]->id << "    Memory: " << hex << var_table.table[i]->location << "   Initialised: " << var_table.table[i]->initialised << endl; 
}

void yyerror(char const *s)
{
	cout << "Error: " << s << ", line: " << lineno << endl;
	exit(-1);
}
