%{
#include <iostream>
#include <fstream>
#include <cstdlib>
#include <string>
#include <iomanip>
#include <sstream>
#include "yacc.tab.h"
#include "varTable.h"
#include "procTable.h"
using namespace std;

/* LEX/YACC FUNCTIONS & VARIABLES */
int yylex();
void yyerror(char const *);
extern int lineno;

/* USER-WRITTEN FUNCTIONS & VARIABLES */
void addVar(char *);
void addArr(char *, int, int);
void generateAssignment(char *);
void generateArrayAssignment(char *);
void generateFunctionAssignment(char *);
void generateArrayFunctionAssignment(char *);
void generateCompare(char *, int);
void processBuffer();
void procedureDeclaration(char *);
void functionDeclaration(char *);
void procedureCall(char *);
void functionCall(char *);
void writeHeaders();
void writeForVar(int, char *);
void writeForConst(int, int);
void writeForFooter(int);
void writeText(char *);
void writeVar(char *);
void writeArr(char *);
void readArr(char *);
void loadReadWriteVar(char*, bool);
void loadExprVar(char*, int);
ofstream out;
string outFileName;
VarTable varTable;
ProcTable procTable;
unsigned int assignAddress = 0;
unsigned int ifWhileCount = 0; 
unsigned int loopCount = 0;		/* The variables ifWhileCount and loopCount count the number of if/while statements and for loops in the pascal file.
					 * Their values are appended to the labels in the assembly file, so that their names are not the same.
					 * The reason why if/while share the same counter, is because they both depend on boolean value
					 * and the generateCompare() function is used to compare values in two registers and take appropriate branch. */
bool first = true;			/* This variable indicates, whether we are processing the first two factors in an expression. Different
					 * code is generated for the first two factors and any subsequent in the same term */
stringstream assignStream;		/* This is a buffer for code generated to evaluate an expression. It is used in processBuffer() function
					 * to write its contents to the output file */
vector<char *> var_idents;
stringstream varIndexString;
%}

/* TOKENS, TYPES OF NONTERMINALS, UNION */
%token PBEGIN END PROGRAM IF THEN ELSE TO DO VAR INT ARRAY OF
PLUS MINUS MUL DIV LT GT LE GE NE EQ READ WRITE WRITELN PROCEDURE FUNCTION
OPAREN CPAREN OSQPAREN CSQPAREN SEMICOLON COLON COMMA ASSIGNOP DOT DOTDOT

%union
{
	int ival;
	char *sval;
	bool bval;

	struct termT
	{
		char* id;
		bool var;
	} termType;
}
%token <ival> FOR
%token <ival> WHILE
%token <termType> NUMBER
%token <termType> IDENTIFIER
%token <sval> TEXT
%type  <bval> addop
%type  <bval> mulop
%type  <ival> relop if
%type  <termType> num factor term expression var array_assignment

%expect 1    //suppress one shift/reduce conflict from being reported, this is an unharmful dangling else issue
/* GRAMMAR RULES */
%%

program			: /* empty program */
			| program_header var_declarations proc_func_declarations
			{
				out << endl << "\tENTRY" << endl << endl;
			} block DOT
			{
				out << "\tSWI SWI_Exit" << endl;
				out << "\n\tEND" << endl;
			};
/* finds program header */
program_header		: PROGRAM IDENTIFIER SEMICOLON
			{
				out << "\tAREA " << $2.id << ",CODE,READWRITE" << endl << endl;
				writeHeaders();
				delete[] $2.id;
			};

/* finds variable declarations and updates the symbol table (varTable.cpp) with appropriate entries */
var_declarations	: 
			| VAR var_list;

var_list		: var_list var_line
			| var_line;

var_line		: var_identifiers COLON var_type SEMICOLON
			{
				for(int i = 0; i < var_idents.size(); i++)
				{
					addVar(var_idents[i]);
					delete[] var_idents[i];
				}
				var_idents.clear();
			}
			| var_identifiers COLON ARRAY OSQPAREN NUMBER DOTDOT NUMBER CSQPAREN OF var_type SEMICOLON
			{
				for(int i = 0; i < var_idents.size(); i++)
				{
					addArr(var_idents[i], atoi($5.id), atoi($7.id));
					delete[] var_idents[i];
				}
				var_idents.clear();
			};

var_identifiers		: IDENTIFIER
			{
				var_idents.push_back($1.id);
			}
			| var_identifiers COMMA IDENTIFIER
			{
				var_idents.push_back($3.id);
			};

/* the supported variable type is INTEGER */
var_type		: INT;

/* declarations of functions and procedures */
proc_func_declarations	: proc_func_declarations proc_declaration
			| proc_func_declarations func_declaration
			| proc_declaration
			| func_declaration;

proc_declaration	: PROCEDURE IDENTIFIER arguments SEMICOLON
			{
				procedureDeclaration($2.id);
				out << $2.id << endl;
				out << "\tSTMED r13!, {r0-r12, r14}" << endl << endl;

				var_idents.clear();
				delete[] $2.id;
			}
			var_declarations block SEMICOLON
			{
				out << endl << "\tLDMED r13!, {r0-r12, r15}" << endl;
			};

func_declaration	: FUNCTION IDENTIFIER arguments COLON var_type SEMICOLON
			{
				functionDeclaration($2.id);
				out << $2.id << endl;
				out << "\tSTMED r13!, {r0-r12, r14}" << endl << endl;

				var_idents.clear();
				delete[] $2.id;
			}
			var_declarations block SEMICOLON
			{
				out << endl << "\tLDMED r13!, {r0-r12, r15}" << endl;
			};

arguments		: /* no arguments */
			| OPAREN var_identifiers COLON var_type CPAREN;

/* defines a block, enclosed between BEGIN and END keywords */
block			: PBEGIN statement_list END;

statement_list		: statement_list statement SEMICOLON
			| statement SEMICOLON;

/* defines all types of statements */
statement		: assignment_statement
			| if_statement
			| for_loop
			| while_loop
			| readVar
			| writeN
			| writeln
			| procedure_call;

/* defines assignment statement */
assignment_statement	: IDENTIFIER ASSIGNOP expression //expression assignment to variable
			{
				generateAssignment($1.id);
				delete[] $1.id;
			}
			| array_assignment ASSIGNOP expression
			{
				generateArrayAssignment($1.id);
				delete[] $1.id;
			}
			| IDENTIFIER ASSIGNOP function_call
			{
				generateFunctionAssignment($1.id);
				delete[] $1.id;
			}
			| array_assignment ASSIGNOP function_call
			{
				generateArrayFunctionAssignment($1.id);
				delete[] $1.id;
			};

array_assignment	: IDENTIFIER OSQPAREN expression CSQPAREN
			{
				varIndexString << assignStream.str();
				assignStream.str(string());
				$$.id = $1.id;
			};

/* defines that if statement may be if->then->else or if->then only */
if_statement		: if_then_statement
			| if_then_else_statement;

/* defines if->then statement */
if_then_statement	: if boolean_part then_part {out << "else" << $1 << endl;};

/* defines if->then->else statement */
if_then_else_statement	: if boolean_part then_part ELSE {out << "\tB then" << $1 << endl << "else" << $1 << endl;} loop_body {out << "then" << $1 << endl;};

/* if we find an IF token, increment the ifWhileCount and save its value as an attribute of the IF token for a given statement */
if			: IF {$$ = ++ifWhileCount;};

then_part		: THEN loop_body;

/* defines the boolean value determining bahaviour of if and while statements */
boolean_part		: OPAREN boolean_value CPAREN
			| boolean_value;

boolean_value		: IDENTIFIER relop expression
			{
				generateCompare($1.id, $2);
				delete[] $1.id;
			};

/* defines for loop, increments the for loop counter and saves its value in the FOR keyword for a given loop */
for_loop		: FOR start_value TO var
			{
				$1 = ++loopCount;
				writeForVar($1, $4.id);

				delete[] $4.id;
			}
			  DO loop_body
			{
				writeForFooter($1);
			}
			| FOR start_value TO num
			{
				$1 = ++loopCount;
				int temp = atoi($4.id);
				writeForConst($1, temp);
				delete[] $4.id;
			}
			  DO loop_body
			{
				writeForFooter($1);
			};

/* defines the start value of the for loop */
start_value		: OPAREN assignment_statement CPAREN
			| assignment_statement;

/* defines while loop */
while_loop		: WHILE {$1 = ++ifWhileCount; out << "while" << ifWhileCount << endl;} boolean_part DO loop_body {out << "\tB while" << $1 << endl << "else" << $1 << endl;};

/* defines what can be in the loop body */
loop_body		: block
			| assignment_statement
			| for_loop
			| while_loop
			| if_statement
			| readVar
			| writeN
			| writeln
			| procedure_call;

/* defines the read(x); function */
readVar			: READ OPAREN IDENTIFIER CPAREN
			{
				out << "\tBL READR3_" << endl;
				loadReadWriteVar($3.id, false);
				out << "\tSTR R3, [R12]" << endl;
				delete[] $3.id;
			}
			| READ OPAREN IDENTIFIER OSQPAREN expression CSQPAREN CPAREN
			{
				readArr($3.id);
				delete[] $3.id;
			};

/* defines the write(x); function, the compiler supports write functions such as write('Arbitrary string, var1, 'arbitrary string, var2); */
writeN			: WRITE OPAREN write_body CPAREN;

/* defines the writeln(x); function*/
writeln			: WRITELN OPAREN write_body CPAREN
			{
				out << "\tMOV R0, #0xA" << endl;
				out << "\tSWI SWI_WriteC" << endl;
			};

write_body		: write_body COMMA TEXT
			{
				writeText($3);
				delete[] $3;
			}
			| write_body COMMA IDENTIFIER
			{
				writeVar($3.id);
				delete[] $3.id;
			}
			| write_body COMMA IDENTIFIER OSQPAREN expression CSQPAREN
			{
				writeArr($3.id);
				delete[] $3.id;
			}
			| TEXT
			{
				writeText($1);
				delete[] $1;
			}
			| IDENTIFIER
			{
				writeVar($1.id);
				delete[] $1.id;
			}
			| IDENTIFIER OSQPAREN expression CSQPAREN
			{
				writeArr($1.id);
				delete[] $1.id;
			};

/* defines procedure and function calls */
procedure_call		: IDENTIFIER OPAREN passed_arguments CPAREN
			{
				procedureCall($1.id);
				delete[] $1.id;
			};

function_call		: IDENTIFIER OPAREN passed_arguments CPAREN
			{
				functionCall($1.id);
				delete[] $1.id;
			};

passed_arguments	: /* no passed arguments */
			| arg_identifiers;

arg_identifiers		: IDENTIFIER
			{
				var_idents.push_back($1.id);
			}
			| NUMBER
			{
				var_idents.push_back($1.id);
			}
			| arg_identifiers COMMA IDENTIFIER
			{
				var_idents.push_back($3.id);
			}
			| arg_identifiers COMMA NUMBER
			{
				var_idents.push_back($3.id);
			};

/* defines an expression */
expression		: expression addop term
			{
				if($2 == true)
				{
					if($3.id != NULL)
					{
						if($3.var == true)
						{
							loadExprVar($3.id, 1);
							assignStream << "\tADD R0, R0, R1\n";
						}
						else
							assignStream << "\tADD R0, R0, #0x" << hex << atoi($3.id) << "\n";

						delete[] $3.id;
					}
					else
						assignStream << "\tADD R0, R0, R1\n";
				}
				else
				{
					if($3.id != NULL)
					{
						if($3.var == true)
						{
							loadExprVar($3.id, 1);
							assignStream << "\tSUB R0, R0, R1\n";
						}
						else
							assignStream << "\tSUB R0, R0, #0x" << hex << atoi($3.id) << "\n";

						delete[] $3.id;
					}
					else
						assignStream << "\tSUB R0, R0, R1\n";
				}
				first = true;
			}
			| term
			{
				if($1.id != NULL)
				{
					if($1.var == true)
					{
						loadExprVar($1.id, 1);
						assignStream << "\tADD R0, R0, R1\n";
					}
					else
						assignStream << "\tADD R0, R0, #0x" << hex << atoi($1.id) << "\n";
			
					delete[] $1.id;
				}
				else
					assignStream << "\tADD R0, R0, R1\n";

				first = true;
			};

term			: term mulop factor
			{
				if(first == true)
				{
					if($1.var == true)
						loadExprVar($1.id, 2);
					else
						assignStream << "\tMOV R2, #0x" << hex << atoi($1.id) << "\n";

					if($3.var == true)
						loadExprVar($3.id, 3);
					else
						assignStream << "\tMOV R3, #0x" << hex << atoi($3.id) << "\n";

					if($2 == true)
						assignStream << "\tMUL R1, R2, R3\n";
					else
						assignStream << "\tBL DIVR2R3\n";

					delete[] $1.id;
					delete[] $3.id;
				}
				else
				{
					assignStream << "\tMOV R2, R1\n";

					if($3.var == true)
						loadExprVar($3.id, 3);
					else
						assignStream << "\tMOV R3, #0x" << hex << atoi($3.id) << "\n";

					if($2 == true)
						assignStream << "\tMUL R1, R2, R3\n";
					else
						assignStream << "\tBL DIVR2R3\n";

					delete[] $1.id;
					delete[] $3.id;
				}

				first = false;
				$$.id = NULL;
			}
			| factor {$$ = $1;};

factor			: var {$$ = $1;}
			| num {$$ = $1;};

addop			: PLUS {$$ = true;}
			| MINUS {$$ = false;};

mulop			: MUL {$$ = true;}
			| DIV {$$ = false;};

var			: IDENTIFIER {$1.var = true; $$ = $1;};

num			: NUMBER {$1.var = false; $$ = $1;};

relop			: LT {$$ = 5;}
			| GT {$$ = 4;}
			| LE {$$ = 3;}
			| GE {$$ = 2;}
			| EQ {$$ = 1;}
			| NE {$$ = 0;};

%%
/*	------------------------------- MAIN -------------------------------	 */

int main(int argc, char* argv[])
{	
	/* 
	 *  the correct way to run the program is:
	 *  ./ARM_mgb10 OUTPUT_FILE_NAME < PASCAL_FILE_PATH
	 *  therefore any number of command line parameters different than 2 is invalid
	 */
	if(argc == 1)
	{
		cout << "**********************************************************************" << endl;
		cout << "* 			   Pascal -> ARM                             *" << endl;
		cout << "*								     *" << endl;
		cout << "* To run the program, type:					     *" << endl;
		cout << "* ./ARM_mgb10 PATH_TO_OUTPUT_FILE < PATH_TO_INPUT_FILE		     *" << endl;
		cout << "*								     *" << endl;
		cout << "* The generated code will appear in the specified file.		     *" << endl;
		cout << "* Any errors will appear in the stdout.				     *" << endl;
		cout << "*								     *" << endl;
		cout << "**********************************************************************" << endl;
	}
	else if(argc == 2)
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
/* 	------------------------------- MAIN END -------------------------------	*/

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
		varTable.addVariable(c, false, 0, 0);
	else				  //if the variable has been already declared, terminate
	{
		string err("Redeclared variable '");
		err.append(c); err.append("'");
		yyerror(err.c_str());
	}
}

void addArr(char *c, int st, int en)
{
	if(en - st < 0)
	{
		string err("Array '");
		err.append(c); err.append("' with negative dimensions.");
		yyerror(err.c_str());
	}
	
	if(varTable.lookup(c) == NULL)    //check if the variable has not been declared already
		varTable.addVariable(c, true, st, en);
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
			
	out << "\tLDR R12, =0x" << hex << assignVar->location << endl; //load to R12 the address of the variable
	assignAddress = assignVar->location;			//save the address of the most recently assigned variable, used in for loop
	out << "\tSTR R0, [R12]" << endl;	 //after data processing, store the variable in memory			
	
	assignVar->initialised = true;		//flag that the variable has been initialised
}

void generateFunctionAssignment(char *c)
{
	varEntry *assignVar = varTable.lookup(c); //check if the variable to which assign to was declared
		
	if(assignVar == NULL)          //if the variable has not been declared
	{
		string err("Undeclared variable '");
		err.append(c); err.append("'");
		yyerror(err.c_str());
	}	
			
	out << "\tLDR R12, =0x" << hex << assignVar->location << endl; //load to R12 the address of the variable
	assignAddress = assignVar->location;			//save the address of the most recently assigned variable, used in for loop
	out << "\tSTR R6, [R12]" << endl;	 //after data processing, store the variable in memory, the value returned by function was in R6
	
	assignVar->initialised = true;		//flag that the variable has been initialised
}

void generateArrayAssignment(char *c)
{
	varEntry *assignVar = varTable.lookup(c); //check if the variable to which assign to was declared
		
	if(assignVar == NULL)          //if the variable has not been declared
	{
		string err("Undeclared array '");
		err.append(c); err.append("'");
		yyerror(err.c_str());
	}
	else
	{
		if(assignVar->arr == false)
		{
			string err("Not an array '");
			err.append(c); err.append("'");
			yyerror(err.c_str());
		}
		else
		{
			out << "\tMOV R0, #0x0" << endl;
			processBuffer();
			out << "\tMOV R9, R0" << endl; //assignment result in R9
			out << "\tMOV R0, #0x0" << endl;
			out << varIndexString.str();
			varIndexString.str(string());
			out << "\tLDR R12, =0x" << hex << assignVar->location << endl; //load to R12 the address of the variable
			out << "\tSUB R0, R0, #0x" << hex << assignVar->startindex << endl; //subtract the startindex from the calculated expression in square brackets
			out << "\tMOV R8, #0x4" << endl; 
			out << "\tMOV R7, R0" << endl;
			out << "\tMUL R0, R7, R8" << endl; //multiply the offset by 4
			out << "\tSTR R9, [R12, R0]" << endl;	 //after data processing, store the variable in memory		
		}
	}
}

void generateArrayFunctionAssignment(char *c)
{
	varEntry *assignVar = varTable.lookup(c); //check if the variable to which assign to was declared
		
	if(assignVar == NULL)          //if the variable has not been declared
	{
		string err("Undeclared array '");
		err.append(c); err.append("'");
		yyerror(err.c_str());
	}
	else
	{
		if(assignVar->arr == false)
		{
			string err("Not an array '");
			err.append(c); err.append("'");
			yyerror(err.c_str());
		}
		else
		{
			out << "\tMOV R0, #0x0" << endl;
			out << varIndexString.str();
			varIndexString.str(string());
			out << "\tLDR R12, =0x" << hex << assignVar->location << endl; //load to R12 the address of the variable
			out << "\tSUB R0, R0, #0x" << hex << assignVar->startindex << endl; //subtract the startindex from the calculated expression in square brackets
			out << "\tMOV R8, #0x4" << endl; 
			out << "\tMOV R7, R0" << endl;
			out << "\tMUL R0, R7, R8" << endl; //multiply the offset by 4
			out << "\tSTR R6, [R12, R0]" << endl;	 //after data processing, store the function result fom R6 in memory	
		}
	}
}

void generateCompare(char *c, int i)
{
	out << "\tMOV R0, #0x0" << endl; //reset the register for evaluating the expression in the buffer
	
	processBuffer();

	varEntry *testVar = varTable.lookup(c);

	if(testVar != NULL) //check if the variable which is being compared has been declared
	{
		out << "\tLDR R12, =0x" << hex << testVar->location << endl;
		out << "\tLDR R2, [R12]" << endl; //load the variable to R2
	}				
	else                          //if the variable has not been declared, terminate and display error
	{
		string err("Undeclared variable '");
		err.append(c); err.append("'");
		yyerror(err.c_str());
	}

	out << "\tCMP R2, R0" << endl; //compare the variable on the LHS with the expression on the RHS (f.e. 'A >= 2+3')

	switch(i) //generate appropriate branch
	{
	case 0: //token NE (not equal), else branch is therefore if two values are EQ (equal)
		out << "\tBEQ else" << ifWhileCount << endl;
		break;
	case 1: //token EQ (equal), else branch is therefore if two values are NE (not equal)
		out << "\tBNE else" << ifWhileCount << endl;
		break;
	case 2: //token GE (greater or equal), else branch is therefore if the first value is LT (less than)
		out << "\tBLT else" << ifWhileCount << endl;
		break;
	case 3: //token LE (less or equal), else branch is therefore if the first value is GT (greater than)
		out << "\tBGT else" << ifWhileCount << endl;
		break;
	case 4: //token GT (greater than), else branch is therefore if the first value is LE (less or equal)
		out << "\tBLE else" << ifWhileCount << endl;
		break;
	case 5: //token LT (less than), else branch is therefore if the first value is GE (greater or equal)
		out << "\tBGE else" << ifWhileCount << endl;
		break;
	}			
}

void processBuffer()
{
	out << assignStream.str();  //write the contents of the buffer to the output file
	assignStream.str(string()); /* clear the stringstream, strange way but apparently the class 
					     * has no member function to clear the content of stringstream */
}

void procedureDeclaration(char *p)
{
	if(procTable.lookup(p) == NULL)    //check if the procedure has not been declared already
		procTable.addProcedure(p);
	else				  //if the procedure has been already declared, terminate
	{
		string err("Redeclared function/procedure '");
		err.append(p); err.append("'");
		yyerror(err.c_str());
	}

	procEntry *procPointer = procTable.lookup(p);

	for(int i = 0; i < var_idents.size(); i++) //add all arguments to the appropriate entry in the proc table
	{
		addVar(var_idents[i]);
		varEntry *varTemp = varTable.lookup(var_idents[i]);
		procTable.addArgs(procPointer, varTemp);
		delete[] var_idents[i];
	}
}

void functionDeclaration(char *p)
{
	if(procTable.lookup(p) == NULL)    //check if the procedure has not been declared already
	{
		procTable.addFunction(p);	
		addVar(p); //this variable is holds the return value from the function
	}	
	else				  //if the procedure has been already declared, terminate
	{
		string err("Redeclared function/procedure '");
		err.append(p); err.append("'");
		yyerror(err.c_str());
	}

	procEntry *funcPointer = procTable.lookup(p);

	for(int i = 0; i < var_idents.size(); i++) //add all arguments to the appropriate entry in the proc table
	{
		addVar(var_idents[i]);
		varEntry *varTemp = varTable.lookup(var_idents[i]);
		procTable.addArgs(funcPointer, varTemp);
		delete[] var_idents[i];
	}
}

void procedureCall(char *p)
{
	procEntry *procCall = procTable.lookup(p);

	if(procCall == NULL) //if the procedure with such name does not exist
	{
		string err("Undeclared procedure '");
		err.append(p); err.append("'");
		yyerror(err.c_str());
	}
	else
	{
		if(procCall->function == true)
		{
			string err("'"); err.append(p);
			err.append("' is a function, not a procedure. Use in an assignment statement. ");
			yyerror(err.c_str());
		}
		else
		{
			if(procCall->arg_no != var_idents.size()) //if the number of arguments passed to the procedure is invalid
			{
				char size[5];
				sprintf(size, "%d", (int)var_idents.size());
				string err("Bad procedure call. Procedure '");
				err.append(p); err.append("' does not take "); err.append(size); err.append(" arguments");
				yyerror(err.c_str());
			}
			else
			{
				for(int i = 0; i < var_idents.size(); i++) //for each arguments which needs to be passed to the procedure
				{
					varEntry *procVar = procTable.getVar(procCall, i); //get the local variable in the procedure
					if(var_idents[i][0] < 0x30 || var_idents[i][0] > 0x39) /* if the first char is NOT a digit (any ascii char in range between 0x30 and 0x39)
												* we know that the whole thing is for sure not a variable */
					{
						varEntry *argVar = varTable.lookup(var_idents[i]); //load the variable which has to be passed to the procedure

						if(argVar != NULL) //check if the variable has been declared
						{
							out << "\tLDR R12, =0x" << hex << argVar->location << endl;
						}				
						else                          //if the variable has not been declared, terminate and display error
						{
							string err("Undeclared variable '");
							err.append(var_idents[i]); err.append("'");
							yyerror(err.c_str());
						}

						out << "\tLDR R0, [R12]" << endl;
						out << "\tLDR R12, =0x" << hex << procVar->location << endl;
						out << "\tSTR R0, [R12]" << endl;
					}
					else
					{
						int literal = atoi(var_idents[i]);
						out << "\tMOV R0, #0x" << hex << literal << endl;
						out << "\tLDR R12, =0x" << hex << procVar->location << endl;
						out << "\tSTR R0, [R12]" << endl;
					}

						delete[] var_idents[i];
				}
				out << "\tBL " << p << endl;
			}
		}
	}

	var_idents.clear();
}

void functionCall(char *p)
{
	procEntry *procCall = procTable.lookup(p);

	if(procCall == NULL) //if the procedure with such name does not exist
	{
		string err("Undeclared function '");
		err.append(p); err.append("'");
		yyerror(err.c_str());
	}
	else
	{
		if(procCall->function == false)
		{
			string err("'"); err.append(p);
			err.append("' is a procedure, not a function. Use outside an assignment statement. ");
			yyerror(err.c_str());
		}
		else
		{
			if(procCall->arg_no != var_idents.size()) //if the number of arguments passed to the procedure is invalid
			{
				char size[5];
				sprintf(size, "%d", (int)var_idents.size());
				string err("Bad function call. Function '");
				err.append(p); err.append("' does not take "); err.append(size); err.append(" arguments");
				yyerror(err.c_str());
			}
			else
			{
				for(int i = 0; i < var_idents.size(); i++) //for each arguments which needs to be passed to the procedure
				{
					varEntry *procVar = procTable.getVar(procCall, i); //get the local variable in the procedure
					if(var_idents[i][0] < 0x30 || var_idents[i][0] > 0x39) /* if the first char is NOT a digit (any ascii char in range between 0x30 and 0x39)
												* we know that the whole thing is for sure not a variable */
					{
						varEntry *argVar = varTable.lookup(var_idents[i]); //load the variable which has to be passed to the procedure

						if(argVar != NULL) //check if the variable has been declared
						{
							out << "\tLDR R12, =0x" << hex << argVar->location << endl;
						}				
						else                          //if the variable has not been declared, terminate and display error
						{
							string err("Undeclared variable '");
							err.append(var_idents[i]); err.append("'");
							yyerror(err.c_str());
						}

						out << "\tLDR R0, [R12]" << endl;
						out << "\tLDR R12, =0x" << hex << procVar->location << endl;
						out << "\tSTR R0, [R12]" << endl;
					}
					else
					{
						int literal = atoi(var_idents[i]);
						out << "\tMOV R0, #0x" << hex << literal << endl;
						out << "\tLDR R12, =0x" << hex << procVar->location << endl;
						out << "\tSTR R0, [R12]" << endl;
					}

						delete[] var_idents[i];
				}
				out << "\tBL " << p << endl;
				out << "\tLDR R12, =0x" << hex << varTable.lookup(p)->location << endl;
				out << "\tLDR R6, [R12]" << endl;
			}
		}
	}

	var_idents.clear();
}

void loadExprVar(char *c, int reg)
{
	varEntry *currentVar = varTable.lookup(c);       //get appropriate entry from the variables symbol table

	if(currentVar != NULL) //if the variable which is on the RHS was declared:
	{
		assignStream << "\tLDR R12, =0x" << hex << currentVar->location << endl;
		assignStream << "\tLDR R" << reg << ", [R12]" << endl;
	}
	else //if it wasn't declared, terminate and display error
	{
		string err("Undeclared variable '");
		err.append(c); err.append("'");
		yyerror(err.c_str());
	}
}

void loadReadWriteVar(char *c, bool write)
{
	varEntry *ioVar = varTable.lookup(c);

	if(ioVar != NULL)
	{
		out << "\tLDR R12, =0x" << hex << ioVar->location << endl;
	}				
	else                          //if the variable has not been declared, terminate and display error
	{
		string err("Undeclared variable '");
		err.append(c); err.append("'");
		yyerror(err.c_str());
	}

	if(write == false)
		ioVar->initialised = true;
}

void writeForVar(int loop, char *c)
{
	out << "\tSUB R0, R0, #0x1" << endl;
	out << "\tSTR R0, [R12]" << endl;
	out << "for" << loop << endl << "\tLDR R12, =0x" << hex << assignAddress << endl;
	out << "\tLDR R10, [R12]" << endl;
	out << "\tADD R10, R10, #1" << endl;
	out << "\tSTR R10, [R12]" << endl;
				
	varEntry *finalVar = varTable.lookup(c);

	if(finalVar != NULL) //check if the variable which value is used as final has been declared
	{
		out << "\tLDR R12, =0x" << hex << finalVar->location << endl;
		out << "\tLDR R11, [R12]" << endl; //load the variable to R11
	}				
	else                          //if the variable has not been declared, terminate and display error
	{
		string err("Undeclared variable '");
		err.append(c); err.append("'");
		yyerror(err.c_str());
	}
				
	out << "\tCMP R10, R11" << endl;
	out << "\tBGT forend" << loop << endl;
}

void writeForConst(int loop, int final)
{
	out << "\tSUB R0, R0, #0x1" << endl;
	out << "\tSTR R0, [R12]" << endl;
	out << "for" << loop << endl << "\tLDR R12, =0x" << hex << assignAddress << endl;
	out << "\tLDR R10, [R12]" << endl;
	out << "\tADD R10, R10, #1" << endl;
	out << "\tSTR R10, [R12]" << endl;
	out << "\tMOV R11, #0x" << hex << final << endl;
	out << "\tCMP R10, R11" << endl;
	out << "\tBGT forend" << loop << endl;
}

void writeForFooter(int n)
{
	out << "\tB for" << n << endl;
	out << "forend" << n << endl;
}

void writeText(char *t)
{
	int i = 0;
	while(t[i] != '\0')
	{
		out << "\tMOV R0, #0x" << hex << (int)t[i] << "\t\t;" << t[i] << endl;
		out << "\tSWI SWI_WriteC" << endl;
		i++;
	}
}

void writeVar(char *v)
{
	loadReadWriteVar(v, true);
	out << "\tLDR R0, [R12]" << endl;
	out << "\tBL PRINTR0_" << endl;
}

void writeArr(char *a)
{
	varEntry *ioVar = varTable.lookup(a); //check if the variable to which assign to was declared
		
	if(ioVar == NULL)          //if the variable has not been declared
	{
		string err("Undeclared array '");
		err.append(a); err.append("'");
		yyerror(err.c_str());
	}
	else
	{
		if(ioVar->arr == false)
		{
			string err("Not an array '");
			err.append(a); err.append("'");
			yyerror(err.c_str());
		}
		else
		{
			out << "\tMOV R0, #0x0" << endl;
			processBuffer();
			out << "\tLDR R12, =0x" << hex << ioVar->location << endl; //load to R12 the address of the variable
			out << "\tSUB R0, R0, #0x" << hex << ioVar->startindex << endl; //subtract the startindex from the calculated expression in square brackets
			out << "\tMOV R8, #0x4" << endl; 
			out << "\tMOV R7, R0" << endl;
			out << "\tMUL R1, R7, R8" << endl; //multiply the offset by 4
			out << "\tLDR R0, [R12, R1]" << endl;	 //after calculating offset, load the part of array to registers
			out << "\tBL PRINTR0_" << endl;	
		}
	}
}

void readArr(char *a)
{
	varEntry *ioVar = varTable.lookup(a); //check if the variable to which assign to was declared
		
	if(ioVar == NULL)          //if the variable has not been declared
	{
		string err("Undeclared array '");
		err.append(a); err.append("'");
		yyerror(err.c_str());
	}
	else
	{
		if(ioVar->arr == false)
		{
			string err("Not an array '");
			err.append(a); err.append("'");
			yyerror(err.c_str());
		}
		else
		{
			out << "\tMOV R0, #0x0" << endl;
			processBuffer();
			out << "\tLDR R12, =0x" << hex << ioVar->location << endl; //load to R12 the address of the variable
			out << "\tSUB R0, R0, #0x" << hex << ioVar->startindex << endl; //subtract the startindex from the calculated expression in square brackets
			out << "\tMOV R8, #0x4" << endl; 
			out << "\tMOV R7, R0" << endl;
			out << "\tMUL R1, R7, R8" << endl; //multiply the offset by 4
			out << "\tBL READR3_" << endl;
			//R12 = base address, R1 - offset, R3 - the value that has just been read from stdin
			out << "\tSTR R3, [R12, R1]" << endl;
		}
	}
}

void writeHeaders()
{
	out << ";--------------------------------------------------------------------------------" << endl;
	out << "; SWI constants" << endl;
	out << ";" << endl << endl;

	out << "SWI_WriteC EQU &0 ; output the character in r0 to the screen" << endl;
	out << "SWI_Write0 EQU &2 ; Write a null (0) terminated buffer to the screen" << endl;
	out << "SWI_ReadC EQU &4 ; input character into r0" << endl;
	out << "SWI_Exit EQU &11 ; finish program" << endl << endl;

	out << "; Allocate memory for the stack--Used by subroutines" << endl;
	out << ";--------------------------------------------------------------------------------" << endl;
	out << "STACK_ % 4000 ; reserve space for stack" << endl;
	out << "STACK_BASE ; base of downward-growing stack + 4" << endl;
	out << "ALIGN" << endl << endl;

	out << "; Subroutine to print contents of register 0 in decimal" << endl;
	out << ";--------------------------------------------------------------------------------" << endl;
	out << "; ** REGISTER DESCRIPTION ** " << endl;
	out << "; R0 byte to print, carry count" << endl;
	out << "; R1 number to print" << endl;
	out << "; R2 ... ,thousands, hundreds, tens, units." << endl;
	out << "; R3 addresses of constants, automatically incremented" << endl;
	out << "; R4 holds the address of units" << endl << endl;

	out << "; Allocate 10^9, 10^8, ... 1000, 100, 10, 1 " << endl << endl;

	out << "CMP1_ DCD 1000000000" << endl;
	out << "CMP2_ DCD 100000000" << endl;
	out << "CMP3_ DCD 10000000" << endl;
	out << "CMP4_ DCD 1000000" << endl;
	out << "CMP5_ DCD 100000" << endl;
	out << "CMP6_ DCD 10000" << endl;
	out << "CMP7_ DCD 1000" << endl;
	out << "CMP8_ DCD 100" << endl;
	out << "CMP9_ DCD 10" << endl;
	out << "CMP10_ DCD 1" << endl << endl;

	out << ";Entry point" << endl << endl;

	out << "PRINTR0_" << endl;
	out << "\tSTMED r13!,{r0-r4,r14}" << endl << endl;

	out << "\tCMP R0, #0x0" << endl;
	out << "\tMOVEQ R0, #0x30" << endl;
	out << "\tSWIEQ SWI_WriteC" << endl;
	out << "\tBEQ printEnd" << endl << endl;

	out << "\tMOV R1, R0" << endl << endl;

	out << "; Is R1 negative?" << endl;
	out << "\tCMP R1,#0" << endl;
	out << "\tBPL LDCONST_" << endl;
	out << "\tRSB R1, R1, #0 		;get 0-R1, ie positive version of r1" << endl;
	out << "\tMOV R0, #'-'" << endl;
	out << "\tSWI SWI_WriteC" << endl << endl;

	out << "LDCONST_			;load starting addresses" << endl;
	out << "\tADR R3, CMP1_ 		;used for comparison at the end of printing" << endl;
	out << "\tADD R4, R3, #40 		;determine final address (10 word addresses +4 because of post-indexing)" << endl << endl;

	out << "NEXT0_				;take as many right-0's as you can..." << endl;
	out << "\tLDR R2, [R3], #4" << endl;
	out << "\tCMP R2, R1" << endl;
	out << "\tBHI NEXT0_" << endl << endl;

	out << "NXTCHAR_			;print all significant characters" << endl;
	out << "\tMOV R0, #0" << endl << endl;

	out << "SUBTRACT_" << endl;
	out << "\tCMP R1, R2" << endl;
	out << "\tSUBPL R1, R1, R2" << endl;
	out << "\tADDPL R0,R0, #1" << endl;
	out << "\tBPL SUBTRACT_" << endl << endl;

	out << "\tADD R0, R0, #'0'		;output number of Carries" << endl;
	out << "\tSWI SWI_WriteC" << endl << endl;

	out << "\tLDR R2, [R3], #4	 	;get next constant, ie divide R2/10" << endl << endl;

	out << "\tCMP R3, R4 			;if we have gone past L10, exit function; else take next character" << endl;
	out << "\tBLE NXTCHAR_" << endl << endl;

	out << "printEnd			;end" << endl;

	out << "\tLDMED r13!,{r0-r4,r15} 	;return" << endl << endl << endl;

	out << "; Subroutine to read a reasonably large positive decimal number to R3" << endl;
	out << "; -------------------------------------------------------------------------------" << endl;
	out << "; The idea is simple:" << endl;
	out << "; Keep reading new characters until newline character has been read." << endl;
	out << "; In order to produce meaningful results, the characters are assumed to be digits." << endl;
	out << "; Other characters are however acceptable, yet their value will correspond to the" << endl;
	out << "; ASCII value associated with a given character." << endl;
	out << "; Due to ARM registers being 32-bits wide, trying to enter any number bigger than" << endl;
	out << "; 0xFFFFFFFF (0d 4 294 967 295) will generate overflow and by consequence" << endl;
	out << "; garbage output of the subroutine." << endl << endl;

	out << "READR3_				;entry point" << endl << endl;

	out << "\tSTMED r13!,{r0,r1,r2,r14}	;push current registers onto the stack" << endl << endl;

	out << "\tMOV R3, #0x0		;initialise the output register" << endl;
	out << "\tMOV R1, #0x0		;this is essentially a boolean value, 0 correcponds to positive number, 1 to negative" << endl;
	out << "\tMOV R10, #0xA		;initialise R10 to 10, used for multiplications" << endl;
	out << "start" << endl;
	out << "\tSWI SWI_ReadC		;read char to R0 (value in ASCII)" << endl;
	out << "\tSWI SWI_WriteC	;write the char that has just been read" << endl;
	out << "\tCMP R0, #0xA		;this value corresponds to newline character" << endl;
	out << "\tBEQ start		;if the first character was a NEWLINE, just keep reading" << endl;
	out << "\tCMP R0, #0x2D		;if the first character was a minus" << endl;
	out << "\tMOVEQ R1, #0x1	;move 1 to R1, used at the end to reverse the value in R3" << endl;
	out << "\tBEQ loopread		;read the other characters" << endl << endl;

	out << "\tSUB R0, R0, #0x30	;if the first character was anything else than NEWLINE or -, need to accumulate it in R3" << endl;
	out << "\tMOV R2, R3" << endl;
	out << "\tMUL R3, R2, R10" << endl;	
	out << "\tADD R3, R3, R0" << endl << endl;

	out << "loopread" << endl;
	out << "\tSWI SWI_ReadC		;read char to R0 (value in ASCII)" << endl;
	out << "\tSWI SWI_WriteC	;write the char that has just been read" << endl;
	out << "\tCMP R0, #0xA		;this value corresponds to newline character" << endl;
	out << "\tBEQ end		;stop reading if NEWLINE has been read" << endl;
	out << "\tSUB R0, R0, #0x30	;this value is an ASCII offset for digits, subtract it" << endl;
	out << "\tMOV R2, R3		;temporarily store the current accumulated value in R2, needed for the MUL instruction to work" << endl;
	out << "\tMUL R3, R2, R10	;multiply the current accumulated value by 10" << endl;
	out << "\tADD R3, R3, R0	;add the read digit" << endl;
	out << "\tB loopread		;branch to read next digit" << endl;
	out << "end" << endl;
	out << "\tCMP R1, #0x1		;if the first chracter was a minus" << endl;
	out << "\tRSBEQ R3, R3, #0x0	;get the negative value of R3" << endl << endl;
	
	out << "\tLDMED r13!,{r0,r1,r2,r15}  ;pop values from the stack and return" << endl << endl << endl;

	out << "; Subroutine to divide R2 by R3 and put the result in R1" << endl;
	out << "; -------------------------------------------------------------------------------" << endl;
	out << "; We keep subtracting R3 from R2 until we reach 0 or negative value" << endl;
	out << "; With each subtraction that does not yield in 0 or negative value in R2" << endl;
	out << "; we increment R0 which is the output of the subroutine." << endl;
	out << "; The subroutine also handles all combinations of positive/negative" << endl;
	out << "; division. Ie x/y, x/(-y), (-x)/y and (-x)/(-y) all yield in correct result." << endl;
	out << "; Comments next to each instruction explain how the subroutine works in detail." << endl << endl;

	out << "DIVR2R3" << endl << endl;
	
	out << "\tSTMED r13!, {r2,r3,r4,r14}	;push registers on stack" << endl << endl;
	
	out << "\tMOV R1, #0x0			;initialise R1 (the output) to 0" << endl;
	out << "\tMOV R4, #0x0			;0 at the end in R4 means positive result, 1 means negative" << endl;
	out << "\tCMP R2, #0x0			;check if R2 is positive" << endl;
	out << "\tRSBLT R2, R2, #0x0		;if R2 is negative, get its positive counterpart" << endl;
	out << "\tMOVLT R4, #0x1		;if R2 was negative, indicate that the result should be negative" << endl;
	out << "\tCMP R3, #0x0			;check if R3 is positive" << endl;
	out << "\tBEQ divByZero			;if 0, branch to the label which prints an error message and terminates the program" << endl << endl;

	out << "\tRSBLT R3, R3, #0x0		;if R3 is negative, get its positive counterpart" << endl;
	out << "\tBGT loopdiv			;if R3 was positive, branch to the main loop and perform division" << endl << endl;

	out << "\tCMP R4, #0x0			;if we have not taken branch, it means that R3 was negative, check what is already in R4" << endl;
	out << "\tMOVEQ R4, #0x1		;if R4 is 0, it means that R2 was positive, then indicate negative result" << endl;
	out << "\tMOVNE R4, #0x0		;if R4 is 1, it means that R2 was negative, then two minuses mean plus, indicate positive result" << endl;
	out << "loopdiv				;start the proper division" << endl << endl;

	out << "\tSUB R2, R2, R3		;subtract divisor from dividend" << endl;
	out << "\tCMP R2, #0x0			;check if we went negative already" << endl;
	out << "\tADDGE R1, R1, #0x1		;if positive, or 0, increment R1 (the output)" << endl;
	out << "\tBGT loopdiv			;if positive, perform the subtraction again (no need to branch if 0)" << endl;
	out << "\tCMP R4, #0x1			;check if there is a need to negate the result" << endl;
	out << "\tRSBEQ R1, R1, #0x0		;negate the result if needed" << endl;
	out << "\tB enddiv			;if everything was successful, branch to the end" << endl << endl;

	out << "divByZero" << endl;
	out << "\tMOV R0, #0x44		;D" << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tMOV R0, #0x69		;i" << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tMOV R0, #0x76		;v" << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tMOV R0, #0x69		;i" << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tMOV R0, #0x73		;s" << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tMOV R0, #0x69		;i" << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tMOV R0, #0x6f		;o" << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tMOV R0, #0x6e		;n" << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tMOV R0, #0x20		;" << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tMOV R0, #0x62		;b" << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tMOV R0, #0x79		;y" << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tMOV R0, #0x20		;" << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tMOV R0, #0x30		;0" << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tMOV R0, #0x2e		;." << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tMOV R0, #0x20		;" << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tMOV R0, #0x54		;T" << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tMOV R0, #0x65		;e" << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tMOV R0, #0x72		;r" << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tMOV R0, #0x6d		;m" << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tMOV R0, #0x69		;i" << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tMOV R0, #0x6e		;n" << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tMOV R0, #0x61		;a" << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tMOV R0, #0x74		;t" << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tMOV R0, #0x69		;i" << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tMOV R0, #0x6e		;n" << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tMOV R0, #0x67		;g" << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tMOV R0, #0x2e		;." << endl;
	out << "\tSWI SWI_WriteC" << endl;
	out << "\tSWI SWI_Exit" << endl;
	
	out << "enddiv" << endl;
	out << "\tLDMED r13!, {r2,r3,r4,r15}	;pop registers from stack" << endl << endl;
}
