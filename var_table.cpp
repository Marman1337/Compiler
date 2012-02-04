#include <iostream>
#include <vector>
#include <string>
#include <iomanip>
#include "var_table.h"
using namespace std;

struct var_entry
{
	string id;
	unsigned long location;
	bool initialised;
};

Var_table::Var_table()
{
	var_pointer = 0xE0010000;
}

Var_table::~Var_table()
{
	for(unsigned long i = 0; i < table.size(); i++)
		delete table[i];
}

bool Var_table::addVariable(string n)
{
	if(this->lookup(n) == false)
	{
		var_entry *temp = new var_entry;
		temp->id = n;
		temp->location = this->var_pointer;
		var_pointer += 4;
		temp->initialised = false;

		table.push_back(temp);
		return true;
	}
	else
		return false;
}

var_entry* Var_table::lookup(string n)
{
	for(unsigned long i = 0; i < table.size(); i++)
		if(table[i]->id == n)
			return table[i];

	return NULL;
}

unsigned long Var_table::getLocation(var_entry* entry)
{
	return entry->location;
}

void Var_table::initialise(var_entry* entry)
{
	entry->initialised = true;
}
