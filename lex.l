%{
#include <iostream>
#include "yacc.tab.h"
using namespace std;
%}
%option noyywrap

%%
(BEGIN|begin)			{return BEGINN;}
(END|end)			{return END;}
(PROGRAM|program)	 	{return PROGRAM;}
(IF|if)				{return IF;}
(THEN|then)			{return THEN;}
(ELSE|else)			{return ELSE;}
var				{return VAR;}
shortint			{return SHORTINT;}
integer				{return INT;}
longint				{return LONGINT;}
byte				{return BYTE;}
boolean				{return BOOLEAN;}
char				{return CHAR;}
[a-zA-Z][a-zA-Z0-9]*		{return IDENTIFIER;}
[0-9]+				{return NUMBER;}
[\+|-|\*|/]			{return MATHOP;}
\(				{return OBRACE;}
\)				{return CBRACE;}
;				{return SEMICOLON;}
:				{return COLON;}
,				{return COMMA;}
=				{return EQUALOP;}
:=				{return ASSIGNOP;}
\.				{return DOT;}
[ \t]+ 				{}	/* ignore whitespace */
\{([^}]|[\r\n])*\}		{}	/* matches {} comments */
\(\*([^*]|(\*+[^*\)]))*\*+\)    {}	/* matches (* *) comments */
\/\/.*				{}	/* matches // comments */
\/\*([^*]|(\*+[^*\/]))*\*+\/    {}	/* matches this comments */

%%
