%{
#include <iostream>
#include <cstdlib>
#include <string>
#include <iomanip>
#include "yacc.tab.h"
#include "var_table.h"
using namespace std;

int yylex();
void yyerror(char const *);
extern int lineno;
Var_table var_table;

struct math
{
	int value;
	bool addition;
};

math buffer[100];
int index = 0;
%}

%token PBEGIN END PROGRAM IF THEN ELSE VAR INT
PLUS MINUS MUL DIV LT GT LE GE NE
OPAREN CPAREN SEMICOLON COLON COMMA EQUALOP ASSIGNOP DOT

%union
{
	int ival;
	char *sval;
	bool bval;
}
%token <ival> NUMBER
%token <sval> IDENTIFIER
%type  <bval> addop
%type  <ival> num
%type  <sval> var

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
				var_entry *currentVar = var_table.lookup($1);
				if(currentVar != NULL)
				{
					cout << "\tMOV R0, #0x00000000" << endl;
					cout << "\tLDR R12, =" << hex << currentVar->location << endl;				
				}
				else
				{
					string err("Undeclared variable '");
					err.append($1); err.append("'");
					yyerror(err.c_str());
				}

				for(int i = 0; i < index; i++)
				{
					if(buffer[i].addition == true)
						cout << "\tADD R0, R0, #0x" << hex << buffer[i].value << endl;
					else
						cout << "\tSUB R0, R0, #0x" << hex << buffer[i].value << endl;
				}			
				
				cout << "\tSTR R0, [R12]" << endl;				
			
				index = 0; //reset the index for the next assignment
				
				currentVar->initialised = true;
				delete $1; //delete the string of identifier because goes out of scope, no need for memory leak there...
			}; 

expression		: expression addop num
			{
				buffer[index].value = $3;
				
				if($2 == true)
					buffer[index].addition = true;
				else
					buffer[index].addition = false;

				index++;
			}
			| expression addop var
			| num
			{
				buffer[index].value = $1;
				buffer[index].addition = true;
				index++;			
			}
			| var;

num			: NUMBER {$$ = $1;};
			
var			: IDENTIFIER {$$ = $1;};

addop			: PLUS  {$$ = true}
			| MINUS {$$ = false};

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
