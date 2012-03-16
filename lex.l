%{
#include <iostream>
#include "yacc.tab.h"
using namespace std;
int lineno = 1;
%}
%option noyywrap
%x comment1
%x comment2
%x text

%%
(BEGIN|begin)			{return PBEGIN;}
(END|end)			{return END;}
(PROGRAM|program)	 	{return PROGRAM;}
(ARRAY|array)			{return ARRAY;}
(OF|of)				{return OF;}
(IF|if)				{return IF;}
(THEN|then)			{return THEN;}
(ELSE|else)			{return ELSE;}
(FOR|for)			{return FOR;}
(TO|to)				{return TO;}
(DO|do)				{return DO;}
(WHILE|while)			{return WHILE;}
(VAR|var)			{return VAR;}
(PROCEDURE|procedure)		{return PROCEDURE;}
(FUNCTION|function)		{return FUNCTION;}
(INTEGER|integer)		{return INT;}
(WRITE|write)			{return WRITE;}
(WRITELN|writeln)		{return WRITELN;}
(READ|read)			{return READ;}
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
"["				{return OSQPAREN;}
"]"				{return CSQPAREN;}
";"				{return SEMICOLON;}
":"				{return COLON;}
","				{return COMMA;}
":="				{return ASSIGNOP;}
"."				{return DOT;}
".."				{return DOTDOT;};
[\n\r]				{lineno++;}
[ \t]+ 				{}			 /* ignore whitespacee */

[a-zA-Z][a-zA-Z0-9]*		{char *res = new char[strlen(yytext)+1]; strcpy(res,yytext); yylval.termType.id = res; return IDENTIFIER;}
[0-9]+				{char *res = new char[strlen(yytext)+1]; strcpy(res,yytext); yylval.termType.id = res; return NUMBER;}

"{"				BEGIN(comment1);	 /* matches { ... } comments and counts newlines */
<comment1>[^}\n\r]*		{}
<comment1>[\n\r]		{lineno++;}
<comment1>"}"			BEGIN(INITIAL);

"(*"				BEGIN(comment2);	/* matches (* ... *) comments and counts newlines */
<comment2>[^*\n\r]*		{}
<comment2>"*"+[^*\)\n\r]*	{}
<comment2>[\n\r]		{lineno++;}
<comment2>"*"+")"		BEGIN(INITIAL);

"\'"				BEGIN(text);
<text>[^\'\n\r]*		{char *res = new char[strlen(yytext)+1]; strcpy(res,yytext); yylval.sval = res; return TEXT;}
<text>[\n\r]			{lineno++; BEGIN(INITIAL);}
<text>"\'"			BEGIN(INITIAL);

\/\/.*				{}			/* matches // ... comments */

%%
