#ifndef VARTABLE
#define VARTABLE
#include <iostream>
#include <string>
#include <vector>
using namespace std;

struct varEntry
{
	string id;
	unsigned long location;
	bool initialised;
};

class VarTable
{
public:
	VarTable();
	~VarTable();

	void addVariable(string n);
	varEntry* lookup(string n);
	unsigned long getLocation(varEntry* entry);
	void initialise(varEntry* entry);


	vector<varEntry*> table;
	unsigned long varPointer; //empty-ascending stack of variables
};

#endif
