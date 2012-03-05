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
	bool arr;
	int startindex;
};

class VarTable
{
public:
	VarTable();
	~VarTable();

	void addVariable(string n, bool arr, int startin, int endin);
	varEntry* lookup(string n);
	unsigned long getLocation(varEntry* entry);
	void initialise(varEntry* entry);

	vector<varEntry*> table;
	unsigned long varPointer; //empty-ascending stack of variables
};

#endif
