#include <iostream>
#include <vector>
#include <string>
#include "varTable.h"
using namespace std;

VarTable::VarTable()
{
	varPointer = 0xE001C010;
}

VarTable::~VarTable()
{
	for(unsigned long i = 0; i < table.size(); i++)
		delete table[i];
}

void VarTable::addVariable(string n)
{
	varEntry *temp = new varEntry;
	temp->id = n;
	temp->location = this->varPointer;
	varPointer += 4;
	temp->initialised = false;

	table.push_back(temp);
}

varEntry* VarTable::lookup(string n) //check if the variable has been declared, return pointer to an appropriate entry if so, otherwise NULL
{
	for(unsigned long i = 0; i < table.size(); i++)
		if(table[i]->id == n)
			return table[i];

	return NULL;
}

unsigned long VarTable::getLocation(varEntry* entry) //having a pointer to a variable entry, return its location in the memory
{
	return entry->location;
}

void VarTable::initialise(varEntry* entry) //having a pointer to a variable entry, initialise it
{
	entry->initialised = true;
}
