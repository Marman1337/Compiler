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
ofstream out;
string outFileName;
VarTable varTable;
AssignBuffer buffer;
unsigned long r12 = 0;
unsigned int ifCount = 1;
unsigned int loopCount = 1;
bool inForLoop = false;
string lastAssigned;
string dummyForVariable = "";

%}

%token PBEGIN END PROGRAM IF THEN ELSE FOR TO DO VAR INT
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

assignment_statements	: assignment_statements assignment_statement SEMICOLON
			| assignment_statement SEMICOLON;

assignment_statement	: IDENTIFIER ASSIGNOP expression
			{
				generateAssignment($1);
				delete $1; //delete the string of identifier because goes out of scope, no need for memory leak there...
			}; 

if_statement		: if_then_statement {r12 = 0; ifCount++;}
			| if_then_else_statement {r12 = 0; ifCount++;};

if_then_statement	: IF boolean_part then_part {out << "else" << ifCount;};

if_then_else_statement	: IF boolean_part then_part else_part;

then_part		: THEN then_body;

then_body		: loop_block
			| assignment_statement;

else_part		: ELSE {out << "\tB then" << ifCount << endl << "else" << ifCount;} else_body {out << "then" << ifCount;};

else_body		: loop_block
			| assignment_statement;

boolean_part		: OPAREN boolean_value CPAREN
			| boolean_value;

boolean_value		: IDENTIFIER relop expression
			{
				generateCompare($1, $2);
				delete $1;
			};

loop_block		: PBEGIN assignment_statements END;

for_loop		: FOR start_value TO var DO for_body
			| FOR start_value
			  TO num
			  {
				inForLoop = true; /*mark that we are in the for loop, need for the generateAssignment() function to check for
						    trying to assign to the dummy variable which is illegal */
				dummyForVariable = lastAssigned;     //save the name of the dummy variable
				out << "\tMOV R10, R0\n\tMOV R11, #0x" << hex << $4 << endl << "\tCMP R10, R11" << endl;
				out << "\tBGT forend" << loopCount << endl << "for" << loopCount;
			  }
			  DO for_body
			  {
				out << "\tADD R10, R10, #0x1\n\tCMP R10, R11\n\tBLE for" << loopCount << endl; //generate COMPARE instruction and corresponding branch if LESS or EQUAL
				varEntry *dummyVar = varTable.lookup(dummyForVariable); /* after finished loop, need to store the dummy variable to memory
								its value will be always greater by 1 from the terminating value */
				out << "\tLDR R12, =0x" << hex << dummyVar->location << endl;
				r12 = dummyVar->location;
				out << "\tSTR R10, [R12]\nforend" << loopCount;
				inForLoop = false;     //mark that it is the end of for loop
				dummyForVariable = ""; //reset the dummy variable string

				loopCount++;
			  };

start_value		: OPAREN assignment_statement CPAREN
			| assignment_statement;

for_body		: loop_block
			| assignment_statement;

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
int main(int argc, char* argv[])
{
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
	
	out.close();       //quick and effortless way to clear the file which was previously written to
	out.open(outFileName.c_str());
	out.close();
	
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
		
	if(assignVar == NULL)          //if the variable has not been declared
	{
		string err("Undeclared variable '");
		err.append(n); err.append("'");
		yyerror(err.c_str());
	}
	
	if(inForLoop == true && assignVar->id == dummyForVariable)
	{
		string err("Trying to modify the for loop dummy variable '");
		err.append(dummyForVariable); err.append("'");
		err.append(" inside the for loop body. Illegal");
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

void generateCompare(char *n, int c)
{
	varEntry *testVar = varTable.lookup(n);

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
		err.append(n); err.append("'");
		yyerror(err.c_str());
	}

	out << "\tMOV R0, #0x0" << endl; //reset the register for evaluating the expression in the buffer

	processBuffer();

	out << "\tCMP R2, R0" << endl; //compare the variable on the LHS with the expression on the RHS (f.e. 'A >= 2+3')

	switch(c) //generate appropriate branch
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

			if(inForLoop == true && currentVar->id == dummyForVariable)  //if we are in for loop and the dummy variable is on the RHS of the assignment
			{
				if(temp->addition == true)
					out << "\tADD R0, R0, R10" << endl;
				else
					out << "\tSUB R0, R0, R10" << endl;
			}
			else
			{
				if(currentVar != NULL)
				{
					if(currentVar->initialised == false)
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
	}
	
	buffer.flush(); //reset the buffer for the next assignment	
}
