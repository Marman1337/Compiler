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
};

class ProcTable
{
public:
	ProcTable();
	~ProcTable();
	void addProcedure(string id);
	procEntry* lookup(string id);
	bool addArgToProc(procEntry* procedure, varEntry* variable);
	varEntry* getVar(procEntry* procedure, int index);
	
	vector<procEntry*> table;
};

#endif
