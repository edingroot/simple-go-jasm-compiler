%{
/**
 *  PLEASE COMPILE THE GENERATED CODE WITH C++ compiler (g++).
 */
/* SECTION1: Declarations - Definitions */
#include <stdio.h>
#include <ctype.h>
#include <string>
#include "y.tab.hpp"

// ---------- Option Marcos ----------
// #define PRINT_LINES
// #define PRINT_TOKENS
// ---------- /Option Marcos ----------

#define MAX_LINE_LEN  256

#define LIST          strcat(buf, yytext)

#ifdef PRINT_TOKENS
    #define token(t)  { LIST; printf(t < 255 ? "<token:'%c'>\n" : "<token:@%d>\n", t); return t; }
#else
    #define token(t)  { LIST; return t; }
#endif

int lineNum = 1;
int t_num;
char buf[MAX_LINE_LEN];
char buf_str[MAX_LINE_LEN];

%}

%x X_C_COMMENT X_STR_LIT

L            [a-zA-Z_]
word        ({L}|[0-9])


/* SECTION2: Transition Rules - Token Descriptions and actions */
%%

"/*"                { /*" for C editor syntax hightlighting */
                        LIST;
                        BEGIN(X_C_COMMENT);
                    }
<X_C_COMMENT>\n     {
                        LIST;
#ifdef PRINT_LINES
                        printf("%d: %s", lineNum++, buf);
#endif
                        buf[0] = '\0';
                    }
<X_C_COMMENT>.      { LIST; }
<X_C_COMMENT>"*/"   {
                        LIST;
                        BEGIN(INITIAL);
                    }

\/\/.*?\n           { // Single line comment
                        LIST;
#ifdef PRINT_LINES
                        printf("%d: %s", lineNum++, buf);
#endif
                        buf[0] = '\0';
                    }
\n                  {
                        LIST;
#ifdef PRINT_LINES
                        printf("%d: %s", lineNum++, buf);
#endif
                        buf[0] = '\0';
                    }
[ \t]*              { LIST; }

\"                     { /*" for C editor syntax hightlighting */
                        LIST;
                        BEGIN(X_STR_LIT);
                    }
<X_STR_LIT>([^"]*)+ {
                        LIST;
                        strcat(buf_str, yytext);
                    }
<X_STR_LIT>"\"\""   {
                        LIST;
                        strcat(buf_str, "\"");
                    }
<X_STR_LIT>\"       { /*" for C editor syntax hightlighting */
                        // Handle strings
                        LIST;
#ifdef PRINT_TOKENS
                        printf("<string:%s>\n", buf_str);
#endif
                        strcpy(yylval.t_str, buf_str);
                        buf_str[0] = '\0';
                        BEGIN(INITIAL);
                        return STRING_LITERAL;
                    }

"+"                 { token(yytext[0]); }
"-"                 { token(yytext[0]); }
"*"                 { token(yytext[0]); }
"/"                 { token(yytext[0]); }
"^"                 { token(yytext[0]); }
"%"                 { token(yytext[0]); }
"<"                 { token(yytext[0]); }
">"                 { token(yytext[0]); }
"="                 { token(yytext[0]); }
"&"                 { token(yytext[0]); }
"|"                 { token(yytext[0]); }
"!"                 { token(yytext[0]); }

"<="                { token(LE_OP); }
">="                { token(GE_OP); }
"=="                { token(EQ_OP); }
"!="                { token(NE_OP); }
"+="                { token(ADD_ASSIGN); }
"-="                { token(SUB_ASSIGN); }
"*="                { token(MUL_ASSIGN); }
"/="                { token(DIV_ASSIGN); }

","                 { token(yytext[0]); }
":"                 { token(yytext[0]); }
";"                 { token(yytext[0]); }
"("                 { token(yytext[0]); }
")"                 { token(yytext[0]); }
"["                 { token(yytext[0]); }
"]"                 { token(yytext[0]); }
"{"                 { token(yytext[0]); }
"}"                 { token(yytext[0]); }

"bool"              { token(BOOL); }
"break"             { token(BREAK); }
"case"              { token(CASE); }
"const"             { token(CONST); }
"continue"          { token(CONTINUE); }
"default"           { token(DEFAULT); }
"else"              { token(ELSE); }
"false"             { yylval.t_int = 0; token(FALSE); }
"for"               { token(FOR); }
"func"              { token(FUNC); }
"go"                { token(GO); }
"if"                { token(IF); }
"import"            { token(IMPORT); }
"int"               { token(INT); }
"nil"               { token(NIL); }
"print"             { token(PRINT); }
"println"           { token(PRINTLN); }
"real"              { token(REAL); }
"return"            { token(RETURN); }
"string"            { token(STRING); }
"struct"            { token(STRUCT); }
"switch"            { token(SWITCH); }
"true"              { yylval.t_int = 1; token(TRUE); }
"type"              { token(TYPE); }
"var"               { token(VAR); }
"void"              { token(VOID); }
"while"             { token(WHILE); }

[0-9]*\.[0-9]+      {
                        LIST;
                        sscanf(yytext, "%lf", &yylval.t_double);
#ifdef PRINT_TOKENS
                        printf("<real:%x>\n", yylval.t_double);
#endif
                        return REAL_CONST;
                    }
[0-9]*              {
                        LIST;
                        yylval.t_int = atoi(yytext);
#ifdef PRINT_TOKENS
                        printf("<integer:%d>\n", yylval.t_int);
#endif
                        return INT_CONST;
                    }
{L}+{word}*         {
                        // Handle identifiers
                        LIST;
#ifdef PRINT_TOKENS
                        printf("<ident:%s>\n", yytext);
#endif
                        strcpy(yylval.t_str, yytext);
                        return IDENTIFIER;
                    }

.                   {
                        LIST;
                        printf("Error at line %d: %s\n", lineNum++, buf);
                        printf("Error: bad character '%s'\n", yytext);
                        exit(-1);
                    }
