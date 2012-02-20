%{
#include <iostream>
#include <fstream>
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
void generateCompare(char *, int);
void processBuffer();
void processForBody();
void forVarAsFinal(char *);
void forConstAsFinal(int);
ofstream out;
string outFileName;
VarTable varTable;
AssignBuffer buffer;
unsigned long r12 = 0;
unsigned int ifCount = 1;     
unsigned int loopCount = 1;   /* the variables ifCount and loopCount count the number of if statements and loops in the pascal file,
			       * and their values are appended to the labels in the assembly file, so that their names are not the same */

string lastAssigned;          //the name of last variable being assigned

%}

%token PBEGIN END PROGRAM IF THEN ELSE TO WHILE DO VAR INT
PLUS MINUS MUL DIV LT GT LE GE NE EQ
OPAREN CPAREN SEMICOLON COLON COMMA ASSIGNOP DOT

%union
{
	int ival;
	char *sval;
	bool bval;
}
%token <ival> FOR
%token <ival> NUMBER
%token <sval> IDENTIFIER
%type  <bval> addop
%type  <ival> num relop
%type  <sval> var

%%

program			: /* empty program */
			| program_header var_declarations block DOT
			{
				out << "\n\tEND\n";
			};

program_header		: PROGRAM IDENTIFIER SEMICOLON
			{
				out << "\tAREA " << $2 << ",CODE,READWRITE\n\n\tENTRY\n\n";
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
			| if_statement
			| for_loop;

assignment_statement	: IDENTIFIER ASSIGNOP expression
			{
				generateAssignment($1);
				delete $1; //delete the string of identifier because goes out of scope, no need for memory leak there...
			}; 

if_statement		: if_then_statement {r12 = 0; ifCount++;}
			| if_then_else_statement {r12 = 0; ifCount++;};

if_then_statement	: IF boolean_part then_part {out << "else" << ifCount << endl;};

if_then_else_statement	: IF boolean_part then_part else_part;

then_part		: THEN then_body;

then_body		: loop_block
			| assignment_statement
			| for_loop;

else_part		: ELSE {out << "\tB then" << ifCount << endl << "else" << ifCount << endl;} else_body {out << "then" << ifCount << endl;};

else_body		: loop_block
			| assignment_statement
			| for_loop;

boolean_part		: OPAREN boolean_value CPAREN
			| boolean_value;

boolean_value		: IDENTIFIER relop expression
			{
				generateCompare($1, $2);
				delete $1;
			};

loop_block		: PBEGIN loop_statements END;

loop_statements		: loop_statements loop_statement SEMICOLON
			| loop_statement SEMICOLON;

loop_statement		: assignment_statement
			| for_loop;

for_loop		: FOR start_value TO var
			{

				$1 = loopCount;
				loopCount++;
				out << "\tSUB R0, R0, #0x2" << endl;
				out << "\tSTR R0, [R12]" << endl;
				out << "for" << $1 << endl << "\tLDR R12, =0x" << hex << r12 << endl;
				out << "\tLDR R10, [R12]" << endl;
				out << "\tADD R10, R10, #1" << endl;
				out << "\tSTR R10, [R12]" << endl;
				
				varEntry *finalVar = varTable.lookup($4);

				if(finalVar != NULL) //check if the variable which value is used as final has been declared
				{
					if(r12 != finalVar->location) //if it has been declared, check if r12 has its address in it
					{
						out << "\tLDR R12, =0x" << hex << finalVar->location << endl;
						r12 = finalVar->location;
					}

					out << "\tLDR R11, [R12]" << endl; //load the variable to R11
				}				
				else                          //if the variable has not been declared, terminate and display error
				{
					string err("Undeclared variable '");
					err.append($4); err.append("'");
					yyerror(err.c_str());
				}
				
				out << "\tCMP R10, R11" << endl;
				out << "\tBEQ forend" << $1 << endl;

				delete $4;
			}
			  DO for_body
			{
				out << "\tB for" << $1 << endl;
				out << "forend" << $1 << endl;
				r12 = 0;
			}
			| FOR start_value TO num
			{
				$1 = loopCount;
				loopCount++;
				out << "\tSUB R0, R0, #0x2" << endl;
				out << "\tSTR R0, [R12]" << endl;
				out << "for" << $1 << endl << "\tLDR R12, =0x" << hex << r12 << endl;
				out << "\tLDR R10, [R12]" << endl;
				out << "\tADD R10, R10, #1" << endl;
				out << "\tSTR R10, [R12]" << endl;
				out << "\tMOV R11, #0x" << hex << $4 << endl;
				out << "\tCMP R10, R11" << endl;
				out << "\tBEQ forend" << $1 << endl;
			}
			  DO for_body
			{
				out << "\tB for" << $1 << endl;
				out << "forend" << $1 << endl;
				r12 = 0;
			};

start_value		: OPAREN assignment_statement CPAREN
			| assignment_statement;

for_body		: loop_block
			| for_loop
			| assignment_statement;

expression		: expression addop num
			{
				buffer.addEntry("", $3, $2, true); //addEntry(string VariableName, int ConstantValue, bool isAddition, bool isConstant)
			}
			| expression addop var
			{
				buffer.addEntry($3, 0, $2, false);
				delete $3;
			}
			| num
			{
				buffer.addEntry("", $1, true, true);			
			}
			| var
			{
				buffer.addEntry($1, 0, true, false);
				delete $1;
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
int main(int argc, char* argv[])
{	
	/* 
	 *  the correct way to run the program is:
	 *  ./ARM_mgb10 OUTPUT_FILE_NAME < PASCAL_FILE_PATH
	 *  therefore any number of command line parameters different than 2 is invalid
	 */
	if(argc == 2)
	{
		outFileName = argv[1];
		out.open(outFileName.c_str());
		
		if(out.is_open() == true)
		{
			yyparse();
			out.close();
		}
		else
			cout << "Could not open: " << outFileName << endl;
	}
	else
	{
		cout << "Error: Invalid number of command line arguments." << endl;
		cout << "The correct way to run the program is:" << endl;
		cout << "PROGRAM_NAME OUTPUT_FILE_NAME < PATH_TO_INPUT_FILE" << endl;
		exit(-1);
	}
}

void yyerror(char const *s)
{
	cout << "Error: " << s << ", line: " << lineno << endl;
	
	/* the next three statements are a quick and effortless way to clear the file which has part of the assembly code
	 * but since there has been an error in the Pascal source, we want to clear the file */
	out.close();
	out.open(outFileName.c_str());
	out.close();
	
	exit(-1);
}

void addVar(char *c)
{
	if(varTable.lookup(c) == NULL)    //check if the variable has not been declared already
		varTable.addVariable(c);
	else				  //if the variable has been already declared, terminate
	{
		string err("Redeclared variable '");
		err.append(c); err.append("'");
		yyerror(err.c_str());
	}
}

void generateAssignment(char *c)
{
	varEntry *assignVar = varTable.lookup(c); //check if the variable to which assign to was declared
		
	if(assignVar == NULL)          //if the variable has not been declared
	{
		string err("Undeclared variable '");
		err.append(c); err.append("'");
		yyerror(err.c_str());
	}	

	out << "\tMOV R0, #0x0" << endl; //reset the register for evaluating the expression in the buffer

	processBuffer();
	
	if(r12 != assignVar->location) //if R12 already has address of the variable, no need to load the same value to it
	{			
		out << "\tLDR R12, =0x" << hex << assignVar->location << endl;
		r12 = assignVar->location;
	}

	out << "\tSTR R0, [R12]" << endl;	 //after data processing, store the variable in memory			
	
	assignVar->initialised = true;		//flag that the variable has been initialised
	lastAssigned = assignVar->id;
}

void generateCompare(char *c, int i)
{
	varEntry *testVar = varTable.lookup(c);

	if(testVar != NULL) //check if the variable which is being compared has been declared
	{
		if(r12 != testVar->location) //if it has been declared, check if r12 has its address in it
		{
			out << "\tLDR R12, =0x" << hex << testVar->location << endl;
			r12 = testVar->location;
		}

		out << "\tLDR R2, [R12]" << endl; //load the variable to R2
	}				
	else                          //if the variable has not been declared, terminate and display error
	{
		string err("Undeclared variable '");
		err.append(c); err.append("'");
		yyerror(err.c_str());
	}

	out << "\tMOV R0, #0x0" << endl; //reset the register for evaluating the expression in the buffer

	processBuffer();

	out << "\tCMP R2, R0" << endl; //compare the variable on the LHS with the expression on the RHS (f.e. 'A >= 2+3')

	switch(i) //generate appropriate branch
	{
	case 0: //token NE (not equal), else branch is therefore if two values are EQ (equal)
		out << "\tBEQ else" << ifCount << endl;
		break;
	case 1: //token EQ (equal), else branch is therefore if two values are NE (not equal)
		out << "\tBNE else" << ifCount << endl;
		break;
	case 2: //token GE (greater or equal), else branch is therefore if the first value is LT (less than)
		out << "\tBLT else" << ifCount << endl;
		break;
	case 3: //token LE (less or equal), else branch is therefore if the first value is GT (greater than)
		out << "\tBGT else" << ifCount << endl;
		break;
	case 4: //token GT (greater than), else branch is therefore if the first value is LE (less or equal)
		out << "\tBLE else" << ifCount << endl;
		break;
	case 5: //token LT (less than), else branch is therefore if the first value is GE (greater or equal)
		out << "\tBGE else" << ifCount << endl;
		break;
	}			
}

void processForBody()
{

}

void forVarAsFinal(char *c)
{

}

void forConstAsFinal(int i)
{

}

void processBuffer()
{
	for(int i = 0; i < buffer.getIndex(); i++) //generate data processing code
	{
		term *temp = buffer.getEntry(i);    //get the part of the assignment to process from the buffer

		if(temp->constant == true)        //if the term is just a constant
		{
			if(temp->addition == true)
				out << "\tADD R0, R0, #0x" << hex << temp->value << endl;
			else
				out << "\tSUB R0, R0, #0x" << hex << temp->value << endl;
		}
		else                            //if the term is a variable
		{
			varEntry *currentVar = varTable.lookup(temp->id);       //get appropriate entry from the variables symbol table

			if(currentVar != NULL) //if the variable which is on the RHS was declared:
			{
				if(currentVar->initialised == false) //if the variable on the RHS has not been initialised, display a warning
					cout << "Warning: Uninitialised variable '" << currentVar->id << "', line: " << lineno << endl;
				
				if(r12 != currentVar->location) //if R12 already has address of the variable, no need to LDR the same value to it
				{
					out << "\tLDR R12, =0x" << hex << currentVar->location << endl;
					r12 = currentVar->location;
				}

				out << "\tLDR R1, [R12]" << endl;

				if(temp->addition == true)
					out << "\tADD R0, R0, R1" << endl;
				else
					out << "\tSUB R0, R0, R1" << endl;
			}
			else //if it wasn't declared, terminate and display error
			{
				string err("Undeclared variable '");
				err.append(currentVar->id); err.append("'");
				yyerror(err.c_str());
			}
		}
	}
	
	buffer.flush(); //reset the buffer for the next assignment	
}
