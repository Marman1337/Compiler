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

struct term
{
	string id;
	int value;
	bool addition;
	bool constant;
};

term buffer[100];
int index = 0;

char id[50];
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
			| program_header var_declarations block DOT {cout << "\nEND\n";};

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
				var_entry *assignVar = var_table.lookup($1); //check if the variable to which assign to was declared
				if(assignVar != NULL)				// if it was declared
				{
					cout << "\tMOV R0, #0x0" << endl;
					//cout << "\tLDR R12, =" << hex << assignVar->location << endl;				
				}
				else //if it wasn't declared, terminate and display error
				{
					string err("Undeclared variable '");
					err.append($1); err.append("'");
					yyerror(err.c_str());
				}

				for(int i = 0; i < index; i++) //generate data processing code
				{
					if(buffer[i].constant == true) //if the term is just a constant
					{
						if(buffer[i].addition == true)
							cout << "\tADD R0, R0, #0x" << hex << buffer[i].value << endl;
						else
							cout << "\tSUB R0, R0, #0x" << hex << buffer[i].value << endl;
					}
					else
					{
						var_entry *currentVar = var_table.lookup(buffer[i].id);
						if(currentVar != NULL)
						{
							if(currentVar->initialised == true)
							{
								cout << "\tLDR R12, =" << hex << currentVar->location << endl;
								cout << "\tLDR R1, [R12]" << endl;
								if(buffer[i].addition == true)
									cout << "\tADD R0, R0, R1" << endl;
								else
									cout << "\tSUB R0, R0, R1" << endl;
							}
							else
							{
								string err("Uninitialised variable '");
								err.append(buffer[i].id); err.append("'");
								yyerror(err.c_str());
							}
						}
						else //if it wasn't declared, terminate and display error
						{
							string err("Undeclared variable '");
							err.append(buffer[i].id); err.append("'");
							yyerror(err.c_str());
						}
					}
					
				}			
				
				cout << "\tLDR R12, =" << hex << assignVar->location << endl;
				cout << "\tSTR R0, [R12]" << endl;	 //after data processing, store the variable in memory			
			
				index = 0; //reset the index for the next assignment
				
				assignVar->initialised = true;
				delete $1; //delete the string of identifier because goes out of scope, no need for memory leak there...
			}; 

expression		: expression addop num
			{
				buffer[index].value = $3;
				buffer[index].constant = true;
				buffer[index].id = "";
				buffer[index].addition = $2;
				index++;
			}
			| expression addop var
			{
				buffer[index].value = 0;
				buffer[index].constant = false;
				buffer[index].id = $3;
				buffer[index].addition = $2;
				index++;
			}
			| num
			{
				buffer[index].value = $1;
				buffer[index].constant = true;
				buffer[index].id = "";
				buffer[index].addition = true;
				index++;			
			}
			| var
			{
				buffer[index].value = 0;
				buffer[index].constant = false;
				buffer[index].id = $1;
				buffer[index].addition = true;
				index++;
			};

num			: NUMBER {$$ = $1;};
			
var			: IDENTIFIER {$$ = $1;};

addop			: PLUS  {$$ = true}
			| MINUS {$$ = false};

%%
int main()
{
	yyparse();
}

void yyerror(char const *s)
{
	cout << "Error: " << s << ", line: " << lineno << endl;
	exit(-1);
}
