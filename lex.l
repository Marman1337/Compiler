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
(VAR|var)			{return VAR;}
(SHORTINT|shortint)		{return SHORTINT;}
(INTEGER|integer)		{return INT;}
(LONGINT|longint)		{return LONGINT;}
(BYTE|byte)			{return BYTE;}
(BOOLEAN|boolean)		{return BOOLEAN;}
(CHAR|char)			{return CHAR;}
[a-zA-Z][a-zA-Z0-9]*		{char *res = new char[strlen(yytext)+1]; strcpy(res,yytext); yylval.sval = res; return IDENTIFIER;}
[0-9]+				{yylval.ival = atoi(yytext); return NUMBER;}
\+				{return PLUS;}
-				{return MINUS;}
\*				{return MUL;}
\/				{return DIV;}
\(				{return OBRACE;}
\)				{return CBRACE;}
;				{return SEMICOLON;}
:				{return COLON;}
,				{return COMMA;}
=				{return EQUALOP;}
:=				{return ASSIGNOP;}
\.				{return DOT;}
[\n\r]				{lineno++;}
[ \t]+ 				{}			 /* ignore whitespace */

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
