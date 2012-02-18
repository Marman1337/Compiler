ARM_mgb10: yacc.tab.o lex.yy.o varTable.o assignmentBuffer.o
	g++ -o ARM_mgb10 lex.yy.o yacc.tab.o varTable.o assignmentBuffer.o

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

varTable.o: varTable.cpp varTable.h
	g++ -c varTable.cpp varTable.h
	rm varTable.h.gch

assignmentBuffer.o: assignmentBuffer.cpp assignmentBuffer.h
	g++ -c assignmentBuffer.cpp assignmentBuffer.h
	rm assignmentBuffer.h.gch

clean:
	rm -f lex.yy.cpp yacc.tab.h yacc.tab.cpp lex.yy.o yacc.tab.o varTable.o assignmentBuffer.o ARM_mgb10

sweep:
	rm -f lex.yy.cpp yacc.tab.h yacc.tab.cpp lex.yy.o yacc.tab.o varTable.o assignmentBuffer.o
