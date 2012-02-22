%{
#include <iostream>
#include "yacc.tab.h"
using namespace std;
int lineno = 1;
%}
%option noyywrap
%x comment1
%x comment2

%%
(BEGIN|begin)			{return PBEGIN;}
(END|end)			{return END;}
(PROGRAM|program)	 	{return PROGRAM;}
(IF|if)				{return IF;}
(THEN|then)			{return THEN;}
(ELSE|else)			{return ELSE;}
(FOR|for)			{return FOR;}
(TO|to)				{return TO;}
(DO|do)				{return DO;}
(WHILE|while)			{return WHILE;}
(VAR|var)			{return VAR;}
(INTEGER|integer)		{return INT;}
(write)				{return WRITE;}
(read)				{return READ;}
"+"				{return PLUS;}
"-"				{return MINUS;}
"*"				{return MUL;}
"/"				{return DIV;}
"<"				{return LT;}
">"				{return GT;}
"<="				{return LE;}
">="				{return GE;}
"<>"				{return NE;}
"="				{return EQ;}
"("				{return OPAREN;}
")"				{return CPAREN;}
";"				{return SEMICOLON;}
":"				{return COLON;}
","				{return COMMA;}
":="				{return ASSIGNOP;}
"."				{return DOT;}
[\n\r]				{lineno++;}
[ \t]+ 				{}			 /* ignore whitespacee */

[a-zA-Z][a-zA-Z0-9]*		{char *res = new char[strlen(yytext)+1]; strcpy(res,yytext); yylval.sval = res; return IDENTIFIER;}
[0-9]+				{yylval.ival = atoi(yytext); return NUMBER;}

"{"				BEGIN(comment1);	 /* matches { ... } comments and counts newlines */
<comment1>[^}\n\r]*		{}
<comment1>[\n\r]		{lineno++;}
<comment1>"}"			BEGIN(INITIAL);

"(*"				BEGIN(comment2);	/* matches (* ... *) comments and counts newlines */
<comment2>[^*\n\r]*		{}
<comment2>"*"+[^*\)\n\r]*	{}
<comment2>[\n\r]		{lineno++;}
<comment2>"*"+")"		BEGIN(INITIAL);

\/\/.*				{}			/* matches // ... comments */

%%
