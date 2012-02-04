comp1: yacc.tab.o lex.yy.o var_table.o
	g++ -o comp1 lex.yy.o yacc.tab.o var_table.o

yacc.tab.o: yacc.tab.cpp
	g++ -c yacc.tab.cpp

lex.yy.o: lex.yy.cpp
	g++ -c lex.yy.cpp

lex.yy.cpp: lex.l
	flex -l lex.l
	mv lex.yy.c lex.yy.cpp

yacc.tab.cpp: yacc.y
	bison -d yacc.y
	rm yacc.tab.c
	bison -v yacc.y
	rm yacc.output
	mv yacc.tab.c yacc.tab.cpp

var_table.o: var_table.cpp var_table.h
	g++ -c var_table.cpp var_table.h
	rm var_table.h.gch

clean:
	rm -f lex.yy.cpp yacc.tab.h yacc.tab.cpp lex.yy.o yacc.tab.o var_table.o comp1

sweep:
	rm -f lex.yy.cpp yacc.tab.h yacc.tab.cpp lex.yy.o yacc.tab.o var_table.o
