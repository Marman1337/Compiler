#ifndef PROCTABLE
#define PROCTABLE
#include <iostream>
#include <string>
#include <vector>
#include "varTable.h"
using namespace std;

struct procEntry
{
	string name;
	vector<varEntry*> arguments;
	int arg_no;
	bool function;
};

class ProcTable
{
public:
	ProcTable();
	~ProcTable();
	void addProcedure(string id);
	void addFunction(string id);
	procEntry* lookup(string id);
	bool addArgs(procEntry* procedure, varEntry* variable);
	varEntry* getVar(procEntry* procedure, int index);
	
	vector<procEntry*> table;
};

#endif
