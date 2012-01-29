comp1: yacc.tab.o lex.yy.o
	g++ -o comp1 lex.yy.o yacc.tab.o

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

clean:
	rm -f lex.yy.cpp yacc.tab.h yacc.tab.cpp lex.yy.o yacc.tab.o comp1

sweep:
	rm -f lex.yy.cpp yacc.tab.h yacc.tab.cpp lex.yy.o yacc.tab.o
