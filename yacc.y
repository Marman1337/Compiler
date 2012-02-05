%{
#include <iostream>
#include <cstdlib>
#include <string>
#include <iomanip>
#include "yacc.tab.h"
#include "varTable.h"
#include "assignmentBuffer.h"
using namespace std;

int yylex();
void yyerror(char const *);
extern int lineno;
VarTable varTable;
AssignBuffer buffer;

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
			| program_header var_declarations block DOT {cout << "\n\tEND\n";};

program_header		: PROGRAM IDENTIFIER SEMICOLON {cout << "\tAREA " << $2 << ",CODE,READWRITE\n\n\tENTRY\n\n"; delete $2};

var_declarations	: VAR var_list;

var_list		: var_identifiers COLON var_type SEMICOLON;

var_identifiers		: IDENTIFIER {varTable.addVariable($1); delete $1}
			| var_identifiers COMMA IDENTIFIER {varTable.addVariable($3); delete $3};

var_type		: INT;

block			: PBEGIN statement_list END;

statement_list		: statement_list statement
			| statement;

statement		: assignment_statement SEMICOLON;

assignment_statement	: IDENTIFIER ASSIGNOP expression
			{
				varEntry *assignVar = varTable.lookup($1); //check if the variable to which assign to was declared
				
				if(assignVar != NULL)				// if it was declared
					cout << "\tMOV R0, #0x0" << endl;
				else //if it wasn't declared, terminate and display error
				{
					string err("Undeclared variable '");
					err.append($1); err.append("'");
					yyerror(err.c_str());
				}

				for(int i = 0; i < buffer.getIndex(); i++) //generate data processing code
				{
					term *temp = buffer.getEntry(i);

					if(temp->constant == true) //if the term is just a constant
					{
						if(temp->addition == true)
							cout << "\tADD R0, R0, #0x" << hex << temp->value << endl;
						else
							cout << "\tSUB R0, R0, #0x" << hex << temp->value << endl;
					}
					else
					{
						varEntry *currentVar = varTable.lookup(temp->id);
						if(currentVar != NULL)
						{
							if(currentVar->initialised == true)
							{
								cout << "\tLDR R12, =" << hex << currentVar->location << endl;
								cout << "\tLDR R1, [R12]" << endl;
								if(temp->addition == true)
									cout << "\tADD R0, R0, R1" << endl;
								else
									cout << "\tSUB R0, R0, R1" << endl;
							}
							else
							{
								string err("Uninitialised variable '");
								err.append(temp->id); err.append("'");
								yyerror(err.c_str());
							}
						}
						else //if it wasn't declared, terminate and display error
						{
							string err("Undeclared variable '");
							err.append(temp->id); err.append("'");
							yyerror(err.c_str());
						}
					}
					
				}			
				
				cout << "\tLDR R12, =" << hex << assignVar->location << endl;
				cout << "\tSTR R0, [R12]" << endl;	 //after data processing, store the variable in memory			
			
				buffer.flush(); //reset the index for the next assignment
				
				assignVar->initialised = true;
				delete $1; //delete the string of identifier because goes out of scope, no need for memory leak there...
			}; 

expression		: expression addop num
			{
				buffer.addEntry("", $3, $2, true); //addEntry(string VariableName, int ConstantValue, bool isAddition, bool isConstant)
			}
			| expression addop var
			{
				buffer.addEntry($3, 0, $2, false);
			}
			| num
			{
				buffer.addEntry("", $1, true, true);			
			}
			| var
			{
				buffer.addEntry($1, 0, true, false);
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
