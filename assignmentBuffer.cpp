#include <iostream>
#include <vector>
#include <string>
#include "assignmentBuffer.h"
using namespace std;

AssignBuffer::AssignBuffer() {}

AssignBuffer::~AssignBuffer()
{
	for(unsigned int i = 0; i < buffer.size(); i++)
		delete buffer[i];
}

void AssignBuffer::addEntry(string i, int v, bool a, bool c)
{
	term *temp = new term;

	temp->id = i;
	temp->value = v;
	temp->addition = a;
	temp->constant = c;

	buffer.push_back(temp);
}

void AssignBuffer::flush()
{
	for(unsigned int i = 0; i < buffer.size(); i++)
		delete buffer[i];
	buffer.clear();	
}

unsigned int AssignBuffer::getIndex()
{
	return buffer.size();
}

term* AssignBuffer::getEntry(int i)
{
	return buffer[i];
}
