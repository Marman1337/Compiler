#ifndef ASSIGNBUF
#define ASSIGNBUF
#include <iostream>
#include <string>
#include <vector>
using namespace std;

struct term
{
	string id;
	int value;
	bool addition;
	bool constant;
};

class AssignBuffer
{
public:
	AssignBuffer();
	~AssignBuffer();
	
	void addEntry(string i, int v, bool a, bool c);
	void flush();
	unsigned int getIndex();
	term* getEntry(int i);

private:
	vector<term*> buffer;
};

#endif
