#include <iostream>
#include <vector>
#include <string>
#include "procTable.h"
#include "varTable.h"
using namespace std;

ProcTable::ProcTable() {}

ProcTable::~ProcTable()
{
	for(unsigned int i = 0; i < table.size(); i++)
		delete table[i];
}

void ProcTable::addProcedure(string id)
{
	procEntry *temp = new procEntry;
	temp->name = id;
	temp->arg_no = 0;

	table.push_back(temp);
}

procEntry* ProcTable::lookup(string id) //check if the procedure has been declared, return pointer to an appropriate entry if so, otherwise NULL
{
	for(unsigned int i = 0; i < table.size(); i++)
		if(table[i]->name == id)
			return table[i];

	return NULL;
}

bool ProcTable::addArgToProc(procEntry* procedure, varEntry* variable)
{
	procedure->arguments.push_back(variable);
	procedure->arg_no++;
}

varEntry* ProcTable::getVar(procEntry* procedure, int index)
{
	if(index > procedure->arguments.size()-1)
		return NULL;
	else
		return procedure->arguments[index];
}
