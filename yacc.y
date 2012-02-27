%{
#include <iostream>
#include <fstream>
#include <cstdlib>
#include <string>
#include <iomanip>
#include <sstream>
#include "yacc.tab.h"
#include "varTable.h"
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
void writeHeaders();
void writeForVar(int, char *);
void writeForConst(int, int);
void writeForFooter(int);
void loadReadWriteVar(char*, bool);
void loadExprVar(char*, int);
ofstream out;
string outFileName;
VarTable varTable;
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

%}

/* TOKENS, TYPES OF NONTERMINALS, UNION */
%token PBEGIN END PROGRAM IF THEN ELSE TO DO VAR INT
PLUS MINUS MUL DIV LT GT LE GE NE EQ READ WRITE WRITELN
OPAREN CPAREN SEMICOLON COLON COMMA ASSIGNOP DOT

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
%type  <termType> num factor term expression var

/* GRAMMAR RULES */
%%

program			: /* empty program */
			| program_header var_declarations block DOT
			{
				out << "\tSWI SWI_Exit" << endl;
				out << "\n\tEND" << endl;
			};

program_header		: PROGRAM IDENTIFIER SEMICOLON
			{
				out << "\tAREA " << $2.id << ",CODE,READWRITE" << endl << endl;
				writeHeaders();
				out << endl << "\tENTRY" << endl << endl;
				delete[] $2.id;
			};

var_declarations	: VAR var_list;

var_list		: var_identifiers COLON var_type SEMICOLON;

var_identifiers		: IDENTIFIER
			{
				addVar($1.id);
				delete[] $1.id; /* The type of IDENTIFIER is a char* to dynamically allocated memory in lex. Need to delete any
						 * reference to IDENTIFIER / NUMBER / TEXT tokens in order to avoid memory leak. */
			}
			| var_identifiers COMMA IDENTIFIER
			{
				addVar($3.id);
				delete[] $3.id;
			};

var_type		: INT;

block			: PBEGIN statement_list END;

statement_list		: statement_list statement SEMICOLON
			| statement SEMICOLON;

statement		: assignment_statement
			| if_statement
			| for_loop
			| while_loop
			| readVar
			| writeN
			| writeln;

assignment_statement	: IDENTIFIER ASSIGNOP expression
			{
				generateAssignment($1.id);
				delete[] $1.id;
			}; 

if_statement		: if_then_statement
			| if_then_else_statement;

if_then_statement	: if boolean_part then_part {out << "else" << $1 << endl;};

if_then_else_statement	: if boolean_part then_part ELSE {out << "\tB then" << $1 << endl << "else" << $1 << endl;} else_body {out << "then" << $1 << endl;};

if			: IF {$$ = ++ifWhileCount;};

then_part		: THEN then_body;

then_body		: loop_block
			| assignment_statement
			| for_loop
			| while_loop
			| if_statement
			| readVar
			| writeN
			| writeln;

else_body		: loop_block
			| assignment_statement
			| for_loop
			| while_loop
			| if_statement
			| readVar
			| writeN
			| writeln;

boolean_part		: OPAREN boolean_value CPAREN
			| boolean_value;

boolean_value		: IDENTIFIER relop expression
			{
				generateCompare($1.id, $2);
				delete[] $1.id;
			};

loop_block		: PBEGIN loop_statements END;

loop_statements		: loop_statements loop_statement SEMICOLON
			| loop_statement SEMICOLON;

loop_statement		: assignment_statement
			| for_loop
			| while_loop
			| if_statement
			| readVar
			| writeN
			| writeln;

for_loop		: FOR start_value TO var
			{
				$1 = ++loopCount;
				writeForVar($1, $4.id);

				delete[] $4.id;
			}
			  DO for_body
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
			  DO for_body
			{
				writeForFooter($1);
			};

start_value		: OPAREN assignment_statement CPAREN
			| assignment_statement;

for_body		: loop_block
			| for_loop
			| while_loop
			| assignment_statement
			| if_statement
			| readVar
			| writeN
			| writeln;

while_loop		: WHILE {$1 = ++ifWhileCount; out << "while" << ifWhileCount << endl;} boolean_part DO while_body {out << "\tB while" << $1 << endl << "else" << $1 << endl;};

while_body		: loop_block
			| for_loop
			| while_loop
			| assignment_statement
			| if_statement
			| readVar
			| writeN
			| writeln;

readVar			: READ OPAREN IDENTIFIER CPAREN 
			{
				out << "\tBL READR3_" << endl;

				loadReadWriteVar($3.id, false);

				out << "\tSTR R3, [R12]" << endl;
				delete[] $3.id;
			};

writeN			: WRITE OPAREN IDENTIFIER CPAREN
			{
				loadReadWriteVar($3.id, true);

				out << "\tLDR R0, [R12]" << endl;
				out << "\tMOV R5, #0x1" << endl; //0x0 for writeln, 0x1 for write
				out << "\tBL PRINTR0_" << endl;
				delete[] $3.id;
			}
			| WRITE OPAREN TEXT CPAREN
			{
				int i = 0;
				while($3[i] != '\0')
				{
					out << "\tMOV R0, #0x" << hex << (int)$3[i] << "\t\t;" << $3[i] << endl;
					out << "\tSWI SWI_WriteC" << endl;
					i++;
				}
				delete[] $3;
			};

writeln			: WRITELN OPAREN IDENTIFIER CPAREN
			{
				loadReadWriteVar($3.id, true);

				out << "\tLDR R0, [R12]" << endl;
				out << "\tMOV R5, #0x0" << endl; //0x0 for writeln, 0x1 for write
				out << "\tBL PRINTR0_" << endl;
				delete[] $3.id;
			}
			| WRITELN OPAREN TEXT CPAREN
			{
				int i = 0;
				while($3[i] != '\0')
				{
					out << "\tMOV R0, #0x" << hex << (int)$3[i] << "\t\t;" << $3[i] << endl;
					out << "\tSWI SWI_WriteC" << endl;
					i++;
				}
				out << "\tMOV R0, #0xA" << endl;
				out << "\tSWI SWI_WriteC" << endl;
				delete[] $3;
			};

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
						{
							assignStream << "\tADD R0, R0, #0x" << hex << atoi($3.id) << "\n";
						}

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
						{
							assignStream << "\tSUB R0, R0, #0x" << hex << atoi($3.id) << "\n";
						}
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
					{
						assignStream << "\tADD R0, R0, #0x" << hex << atoi($1.id) << "\n";
					}
			
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
					{
						assignStream << "\tMUL R1, R2, R3\n";
					}
					else
					{
						assignStream << "\tBL DIVR2R3\n";
					}
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
					{
						assignStream << "\tMUL R1, R2, R3\n";
					}
					else
					{
						assignStream << "\tBL DIVR2R3\n";
					}
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
			
	out << "\tLDR R12, =0x" << hex << assignVar->location << endl; //load to R12 the address of the variable
	assignAddress = assignVar->location;			//save the address of the most recently assigned variable, used in for loop
	out << "\tSTR R0, [R12]" << endl;	 //after data processing, store the variable in memory			
	
	assignVar->initialised = true;		//flag that the variable has been initialised
}

void generateCompare(char *c, int i)
{
	out << "\tMOV R0, #0x0" << endl; //reset the register for evaluating the expression in the buffer
	
	processBuffer();

	varEntry *testVar = varTable.lookup(c);

	if(testVar != NULL) //check if the variable which is being compared has been declared
	{
		if(testVar->initialised == false) //if the variable on the LHS has not been initialised, display a warning
			cout << "Warning: Uninitialised variable '" << testVar->id << "', line: " << lineno << endl;

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
		out << assignStream.str();
		assignStream.str(string()); /* clear the stringstream, strange way but apparently the class 
					     * has no member function to clear the content of stringstream */
}

void loadExprVar(char *c, int reg)
{
	varEntry *currentVar = varTable.lookup(c);       //get appropriate entry from the variables symbol table

	if(currentVar != NULL) //if the variable which is on the RHS was declared:
	{
		if(currentVar->initialised == false) //if the variable on the RHS has not been initialised, display a warning
			cout << "Warning: Uninitialised variable '" << currentVar->id << "', line: " << lineno << endl;
	
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

	if(ioVar != NULL) //check if the variable which is being compared has been declared
	{
		if(write == true && ioVar->initialised == false) //if the variable on the RHS has not been initialised, display a warning
			cout << "Warning: Uninitialised variable '" << ioVar->id << "', line: " << lineno << endl;

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
	out << "CMP10_ DCD 1" << endl;

	out << ";Entry point" << endl << endl;

	out << "PRINTR0_" << endl;
	out << "\tSTMED r13!,{r0-r4,r14}" << endl << endl;

	out << "\tCMP R0, #0x0" << endl;
	out << "\tMOVEQ R0, #0x30" << endl;
	out << "\tSWIEQ SWI_WriteC" << endl;
	out << "\tBEQ newl" << endl << endl;

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

	out << "newl				;print a line bereak" << endl;
	out << "\tCMP R5, #0x0			;0 corresponds to writeln, 1 to write" << endl;
	out << "\tMOVEQ R0, #0xA		;0xA is ASCII for newline" << endl;
	out << "\tSWIEQ SWI_WriteC" << endl << endl;

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
	out << "; garbage output of the subroutine." << endl << endl;;

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
	
	out << "\tLDMED r13!,{r0,r1,r2,r15}  ;pop values from the stack and return" << endl << endl;

	out << "DIVR2R3" << endl;
	out<< "\tSTMED r13!, {r2,r3,r14}	;push registers on stack" << endl;
	out<< "\tMOV R1, #0x0" << endl;
	out<< "loopdiv" << endl;
	out<< "\tSUB R2, R2, R3			;subtract divisor from dividend" << endl;
	out<< "\tCMP R2, #0x0			;check if we went negative already" << endl;
	out<< "\tADDGE R1, R1, #0x1		;if positive, or 0, increment R1 (the output)" << endl;
	out<< "\tBGT loopdiv			;if positive, perform the subtraction again (no need to branch if 0)" << endl;

	out<< "\tLDMED r13!, {r2,r3,r15}	;pop registers from stack" << endl;
}
