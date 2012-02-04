#ifndef VARTABLE
#define VARTABLE
#include <iostream>
#include <string>
#include <vector>
using namespace std;

struct var_entry;

class Var_table
{
public:
	Var_table();
	~Var_table();

	bool addVariable(string n);
	var_entry* lookup(string n);
	unsigned long getLocation(var_entry* entry);
	void initialise(var_entry* entry);

private:
	vector<var_entry*> table;
	unsigned long var_pointer; //empty-ascending stack of variables
};

#endif
