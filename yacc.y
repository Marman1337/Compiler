%{
#include <iostream>
#include <cstdlib>
#include <string>
#include <iomanip>
#include "yacc.tab.h"
#include "varTable.h"
#include "assignmentBuffer.h"
using namespace std;

/* LEX/YACC FUNCTIONS & VARIABLES */
int yylex();
void yyerror(char const *);
extern int lineno;

/* USER-WRITTEN FUNCTIONS & VARIABLES */
void addVar(char *);
void generateAssignment(char *);
VarTable varTable;
AssignBuffer buffer;
unsigned long r12 = 0;

%}

%token PBEGIN END PROGRAM IF THEN ELSE VAR INT
PLUS MINUS MUL DIV LT GT LE GE NE EQ
OPAREN CPAREN SEMICOLON COLON COMMA ASSIGNOP DOT

%union
{
	int ival;
	char *sval;
	bool bval;
}
%token <ival> NUMBER
%token <sval> IDENTIFIER
%type  <bval> addop
%type  <ival> num relop
%type  <sval> var

%%

program			: /* empty program */
			| program_header var_declarations block DOT
			{
				cout << "\n\tEND\n";
			};

program_header		: PROGRAM IDENTIFIER SEMICOLON
			{
				cout << "\tAREA " << $2 << ",CODE,READWRITE\n\n\tENTRY\n\n";
				delete $2;
			};

var_declarations	: VAR var_list;

var_list		: var_identifiers COLON var_type SEMICOLON;

var_identifiers		: IDENTIFIER
			{
				addVar($1);
				delete $1;
			}
			| var_identifiers COMMA IDENTIFIER
			{
				addVar($3);
				delete $3;
			};

var_type		: INT;

block			: PBEGIN statement_list END;

statement_list		: statement_list statement SEMICOLON
			| statement SEMICOLON;

statement		: assignment_statement
			| if_statement;

assignment_statement	: IDENTIFIER ASSIGNOP expression
			{
				generateAssignment($1);
				delete $1; //delete the string of identifier because goes out of scope, no need for memory leak there...
			}; 

if_statement		: if_then_statement
			| if_then_else_statement;

if_then_statement	: IF boolean_value then_part;

if_then_else_statement	: IF boolean_value then_part else_part;

then_part		: THEN then_body {cout << "\tB then" << endl << "else";};

then_body		: assignment_statement
			| if_statement;

else_part		: ELSE else_body {cout << "then";};

else_body		: assignment_statement
			| if_statement;

boolean_value		: IDENTIFIER relop expression
			{
				varEntry *testVar = varTable.lookup($1);

				if(testVar != NULL)
				{
					if(r12 != testVar->location)
					{
						cout << "\tLDR R12, =0x" << hex << testVar->location << endl;
						r12 = testVar->location;
					}
					cout << "\tLDR R0, [R12]" << endl;
				}				
				else                          //if it wasn't declared, terminate and display error
				{
					string err("Undeclared variable '");
					err.append($1); err.append("'");
					yyerror(err.c_str());
				}

				cout << "\tMOV R1, #0x0" << endl;

				for(int i = 0; i < buffer.getIndex(); i++) //generate data processing code
				{
					term *temp = buffer.getEntry(i);    //get the part of the assignment to process from the buffer

					if(temp->constant == true)        //if the term is just a constant
					{
						if(temp->addition == true)
							cout << "\tADD R1, R1, #0x" << hex << temp->value << endl;
						else
							cout << "\tSUB R1, R1, #0x" << hex << temp->value << endl;
					}
					else                            //if the term is a variable
					{
						varEntry *currentVar = varTable.lookup(temp->id);       //get appropriate entry from the variables symbol table

						if(currentVar != NULL)
						{
							if(currentVar->initialised == true)
							{
								if(r12 != currentVar->location) //if R12 already has address of the variable, no need to LDR the same value to it
								{
									cout << "\tLDR R12, =0x" << hex << currentVar->location << endl;
									r12 = currentVar->location;
								}

								cout << "\tLDR R1, [R12]" << endl;
								if(temp->addition == true)
									cout << "\tADD R1, R1, R2" << endl;
								else
									cout << "\tSUB R1, R1, R2" << endl;
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
	
				cout << "\tCMP R0, R1" << endl;

				switch($2) //generate appropriate branch
				{
				case 0:
					cout << "\tBEQ else" << endl;
					break;
				case 1:
					cout << "\tBNE else" << endl;
					break;
				case 2:
					cout << "\tBLT else" << endl;
					break;
				case 3:
					cout << "\tBGT else" << endl;
					break;
				case 4:
					cout << "\tBLE else" << endl;
					break;
				case 5:
					cout << "\tBGE else" << endl;
					break;
				}
	
				buffer.flush(); //reset the buffer for the next assignment
				
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

relop			: LT {$$ = 5;}
			| GT {$$ = 4;}
			| LE {$$ = 3;}
			| GE {$$ = 2;}
			| EQ {$$ = 1;}
			| NE {$$ = 0;};

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



void addVar(char *i)
{
	if(varTable.lookup(i) == NULL)    //check if the variable has not been declared already
		varTable.addVariable(i);
	else				  //if the variable has been already declared, terminate
	{
		string err("Redeclared variable '");
		err.append(i); err.append("'");
		yyerror(err.c_str());
	}
}

void generateAssignment(char *n)
{
	varEntry *assignVar = varTable.lookup(n); //check if the variable to which assign to was declared
				
	if(assignVar != NULL)          //if it was declared
		cout << "\tMOV R0, #0x0" << endl;
	else                          //if it wasn't declared, terminate and display error
	{
		string err("Undeclared variable '");
		err.append(n); err.append("'");
		yyerror(err.c_str());
	}

	for(int i = 0; i < buffer.getIndex(); i++) //generate data processing code
	{
		term *temp = buffer.getEntry(i);    //get the part of the assignment to process from the buffer

		if(temp->constant == true)        //if the term is just a constant
		{
			if(temp->addition == true)
				cout << "\tADD R0, R0, #0x" << hex << temp->value << endl;
			else
				cout << "\tSUB R0, R0, #0x" << hex << temp->value << endl;
		}
		else                            //if the term is a variable
		{
			varEntry *currentVar = varTable.lookup(temp->id);       //get appropriate entry from the variables symbol table

			if(currentVar != NULL)
			{
				if(currentVar->initialised == true)
				{
					if(r12 != currentVar->location) //if R12 already has address of the variable, no need to LDR the same value to it
					{
						cout << "\tLDR R12, =0x" << hex << currentVar->location << endl;
						r12 = currentVar->location;
					}

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
	
	if(r12 != assignVar->location) //if R12 already has address of the variable, no need to LDR the same value to it
	{			
		cout << "\tLDR R12, =0x" << hex << assignVar->location << endl;
		r12 = assignVar->location;
	}
	cout << "\tSTR R0, [R12]" << endl;	 //after data processing, store the variable in memory			
	
	buffer.flush(); //reset the buffer for the next assignment
				
	assignVar->initialised = true;
}
