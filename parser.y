%{
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <libgen.h> // on UNIX/POSIX system
#include <utility> // pair
#include <iostream>
#include <fstream>
#include <stack>
#include <vector>
#include "SymbolTable.hpp"
#include "SymbolEntry.hpp"

// ---------- Option Marcos ----------
// #define ASM_REALTIME_PRINT
// #define DUMP_SYMTABLE
# define EXEC_JAVAA
#define JAVAA_PATH "./javaaPortable/javaa"
// ---------- /Option Marcos ----------

using namespace std;

SymbolValue EMPTY_SV;

vector<SymbolTable*> symTablePool;
vector<SymbolTable*> symTableStack;
SymbolTable *symTable = NULL;
SymbolTable *preCreatedSymTable = NULL;
string className;

// Forward declarations - avoid "implicit declaration of invalid function"
extern FILE *yyin;
int yylex(void);
void dumpSymbolTables();
int yyerror(char *s);
void enterScope(bool genAsm = true);
void exitScope(bool genAsm = true);
SymbolEntry *constDcl(char *ident, SymbolEntry *constExpr);
SymbolEntry *varDcl(char *ident, SymbolType type, SymbolEntry *constExpr);
pair<int, int> findSymbol(char *ident);

#include "codegen.cpp"

%}

%code requires {
    #include "types.hpp"

    // Forward declaration
    class SymbolEntry;
}

%union {
    char              t_str[150];
    int               t_int;
    double            t_double;
    SymbolType        t_symt;
    SymbolTypeList    t_symtl;
    SymbolEntry*      t_syme;
}

// Token definitions - keywords
%token <t_str>      IDENTIFIER STRING_LITERAL
%token <t_int>      INT_CONST TRUE FALSE
%token <t_double>   REAL_CONST
%token VAR TYPE STRUCT CONST VOID STRING INT REAL BOOL NIL
%token IF ELSE GO FOR CONTINUE WHILE SWITCH CASE DEFAULT BREAK
%token IMPORT FUNC RETURN PRINT PRINTLN
// Token definitions - operators
%token LE_OP GE_OP EQ_OP NE_OP ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN DIV_ASSIGN

// Tag type declaration
%type <t_int>   assignment_operator unary_operator
%type <t_symt>  type_specifier
%type <t_symtl> parameter_list primary_expression_list
%type <t_syme>  expression assignment_expression conditional_expression primary_expression 
                postfix_expression unary_expression constant_expression constant parameter_declaration

%nonassoc UMINUS

%start program_unit
%%
constant
    : INT_CONST { 
            $$ = new SymbolEntry(A_CONST, T_INT, &$1, false);
            // May ignored on global var declaration
            asmLastConstLoaded = asmOutputs.size();
            asmAppend("sipush %d", $1);
      }
    | REAL_CONST {
            $$ = new SymbolEntry(A_CONST, T_REAL, &$1, false);
      }
    | TRUE {
            $$ = new SymbolEntry(A_CONST, T_BOOL, &$1, false);
            // May ignored on global var declaration
            asmLastConstLoaded = asmOutputs.size();
            asmAppend("iconst_1");
      }
    | FALSE {
            $$ = new SymbolEntry(A_CONST, T_BOOL, &$1, false);
            // May ignored on global var declaration
            asmLastConstLoaded = asmOutputs.size();
            asmAppend("iconst_0");
      }
    ;

type_specifier
    : VOID          { $$ = T_VOID; }
    | STRUCT        { $$ = T_STRUCT; }
    | STRING        { $$ = T_STRING; }
    | INT           { $$ = T_INT; }
    | REAL          { $$ = T_REAL; }
    | BOOL          { $$ = T_BOOL; }
    ;

unary_operator
    : '+'           { $$ = '+'; }
    | '-'           { $$ = '-'; }
    | '!'           { $$ = '!'; }
    ;

assignment_operator
    : '='           { $$ = '='; }
    | ADD_ASSIGN    { $$ = ADD_ASSIGN; }
    | SUB_ASSIGN    { $$ = SUB_ASSIGN; }
    | MUL_ASSIGN    { $$ = MUL_ASSIGN; }
    | DIV_ASSIGN    { $$ = DIV_ASSIGN; }
    ;

expression
    : assignment_expression
    ;

primary_expression
    : IDENTIFIER {
            pair<int, int> symIndex = findSymbol($1);

            if (symIndex.first != -1) {
                $$ = symTableStack[symIndex.first]->get(string($1));

                if (symIndex.first == 0) {
                    // Global variable
                    if ($$->attr == A_VAR || $$->attr == A_CONST) {
                        // May be ignored on assignment expr
                        asmLastVarLoaded = asmOutputs.size();
                        asmAppend("getstatic %s %s.%s", JVMTYPE_STRING[$$->type], className.c_str(), $$->ident);
                    }

                } else {
                    // TODO: confirm the scope of java stack
                    // May be ignored on assignment expr
                    asmLastVarLoaded = asmOutputs.size();
                    asmAppend("iload %d", symIndex.second);
                }
            } else {
                // Symbol not found among the symbol tables
                dumpSymbolTables();
                yyerror("primary_expression - target symbol is not found among the symbol tables.");
            }
      }
    | constant_expression   { $$ = $1; }
    ;

constant_expression
    : constant { $$ = $1; }
    | STRING_LITERAL {
            $$ = new SymbolEntry(A_CONST, T_STRING, &$1, false);
            asmAppend("ldc \"%s\"", escapeString(string($1)).c_str());
      }
    ;

unary_expression
    : postfix_expression
    | unary_operator unary_expression {
            $$ = $2;
            switch ($1) {
                case '-':
                    asmAppend("ineg");
                    break;
                case '!':
                    asmAppend("ixor");
                    break;
            }
      }
    ;

postfix_expression
    : primary_expression
    | postfix_expression '[' expression ']'
    | postfix_expression '(' ')' {
            asmAppend("invokestatic %s %s.%s()", JVMTYPE_STRING[$1->type], className.c_str(), $1->ident);
      }
    | postfix_expression '(' primary_expression_list ')' {
            asmAppend("invokestatic %s %s.%s(%s)", JVMTYPE_STRING[$1->type], className.c_str(), $1->ident, asmGetParamsString($3).c_str());
      }
    ;

primary_expression_list
    : primary_expression {
            $$.count = 1;
            $$.types[0] = $1->type;
      }
    | primary_expression_list ',' primary_expression {
            $1.types[$1.count++] = $3->type;
            $$ = $1;
      }
    ;

assignment_expression
    : conditional_expression
    | postfix_expression {
            // Remove asm load variable ops generated by $1
            if (asmLastVarLoaded != -1) {
                asmTrimLines(asmLastVarLoaded, 1);
                asmLastVarLoaded = -1;
            }
      } assignment_operator conditional_expression {
            pair<int, int> symIndex = findSymbol($1->ident);
            if (symIndex.first != -1) {
                if (symIndex.first == 0) {
                    // Global variable
                    SymbolEntry *entry = symTableStack[symIndex.first]->get(string($1->ident));
                    asmAppend("putstatic %s %s.%s", JVMTYPE_STRING[entry->type], className.c_str(), entry->ident);
                } else {
                    // TODO: confirm the scope of java stack
                    asmAppend("istore %d", symIndex.second);
                }
            } else {
                // Symbol not found among the symbol tables
                if ($1->attr == A_CONST) {
                    yyerror("syntax error: connot assign to constant.");
                } else {
                    yyerror("assignment_expression - target symbol is not found among the symbol tables.");
                }
            }

            $$ = $4;
      }
    ;

conditional_expression
    : or_expression
    ;

or_expression
    : and_expression
    | or_expression '|' and_expression                      { asmAppend("ior"); }
    ;

and_expression
    : equality_expression
    | and_expression '&' equality_expression                { asmAppend("iand"); }
    ;

equality_expression
    : relational_expression
    | equality_expression EQ_OP relational_expression       { asmLogicOp("ifeq"); }
    | equality_expression NE_OP relational_expression       { asmLogicOp("ifne"); }
    ;

relational_expression
    : additive_expression
    | additive_expression '<' additive_expression           { asmLogicOp("iflt"); }
    | additive_expression '>' additive_expression           { asmLogicOp("ifgt"); }
    | additive_expression LE_OP additive_expression         { asmLogicOp("ifle"); }
    | additive_expression GE_OP additive_expression         { asmLogicOp("ifge"); }
    ;

additive_expression
    : multiplicative_expression
    | additive_expression '+' multiplicative_expression     { asmAppend("iadd"); }
    | additive_expression '-' multiplicative_expression     { asmAppend("isub"); }
    ;

multiplicative_expression
    : unary_expression
    | multiplicative_expression '*' unary_expression        { asmAppend("imul"); }
    | multiplicative_expression '/' unary_expression        { asmAppend("idiv"); }
    | multiplicative_expression '%' unary_expression        { asmAppend("irem"); }
    ;



declaration
    : CONST IDENTIFIER '=' constant_expression              {
                                                                SymbolEntry *entry = constDcl($2, $4);
                                                                asmVarDcl(entry, symTable->insert(entry));
                                                            }
    | VAR IDENTIFIER type_specifier                         {
                                                                SymbolEntry *entry = new SymbolEntry($2, A_VAR, $3, &EMPTY_SV, true);
                                                                // If not global variable declaration
                                                                if (symTableStack.size() > 1)
                                                                    asmAppend("bipush 0");
                                                                asmVarDcl(entry, symTable->insert(entry));
                                                            }
    | VAR IDENTIFIER type_specifier '=' constant_expression {
                                                                SymbolEntry *entry = varDcl($2, $3, $5);
                                                                asmVarDcl(entry, symTable->insert(entry));
                                                            }
    | VAR IDENTIFIER '[' constant_expression ']' type_specifier {
                                                                SymbolEntry *entry = new SymbolEntry($2, A_VAR, $6, &EMPTY_SV, true, true);
                                                                asmVarDcl(entry, symTable->insert(entry));
                                                            }
    ;
declaration_list
    : declaration
    | declaration_list declaration
    ;



statement
    : compound_statement
    | expression
    | selection_statement
    | iteration_statement
    | jump_statement
    | builtin_function
    ;
statement_list
    : statement
    | statement_list statement
    ;

compound_statement
    : comp_start comp_end
    | comp_start statement_list comp_end
    | comp_start declaration_list comp_end
    | comp_start declaration_list statement_list comp_end
    ;
comp_start
    : '{'   { enterScope(!parsingCompoundBranch); }
    ;
comp_end
    : '}'   { exitScope(!parsingCompoundBranch); }
    ;

selection_statement
    : IF '(' expression ')' {
            asmRelOp("ifeq", "Ifalse", asmTagCounter.n_if);
            parsingCompoundBranch = true;
      } statement {
              asmGoto("Iexit", asmTagCounter.n_if);
              asmAppendTag("Ifalse", asmTagCounter.n_if);
      } ELSE statement {
              parsingCompoundBranch = false;
              asmAppendTag("Iexit", asmTagCounter.n_if);
            asmTagCounter.n_if++;
      }
    ;

iteration_statement
    : WHILE '(' expression ')' statement
    | FOR '(' {
            enterScope(false);
      } for_precond_statement {
              asmAppendTag("Ftest", asmTagCounter.n_for);
      } equality_expression {
              asmRelOp("ifeq", "Fexit", asmTagCounter.n_for);
            asmGoto("Fbody", asmTagCounter.n_for);
            asmAppendTag("Fpost", asmTagCounter.n_for);
      } for_post_expression ')' {
              asmGoto("Ftest", asmTagCounter.n_for);
            asmAppendTag("Fbody", asmTagCounter.n_for);
            
            preCreatedSymTable = symTable;
            exitScope(false);
            parsingCompoundBranch = true;
      } statement {
              parsingCompoundBranch = false;
            asmGoto("Fpost", asmTagCounter.n_for);
            asmAppendTag("Fexit", asmTagCounter.n_for);
            asmTagCounter.n_for++;
      }
    ;
for_precond_statement
    : ';'
    | precond_statement ';'
    ;
for_post_expression
    : ';'
    | ';' expression

precond_statement
    : declaration_list
    | expression
    ;

jump_statement
    : GO IDENTIFIER
    | CONTINUE
    | BREAK
    | RETURN                { asmFuncRtn(); }
    | RETURN expression     { asmFuncRtn(); }
    ;

builtin_function
    : PRINT {
            asmAppend("getstatic java.io.PrintStream java.lang.System.out");
      } expression {
              asmAppend("invokevirtual void java.io.PrintStream.print(%s)", JVMTYPE_STRING[$3->type]);
      }
    | PRINTLN {
            asmAppend("getstatic java.io.PrintStream java.lang.System.out");
      } expression {
              asmAppend("invokevirtual void java.io.PrintStream.println(%s)", JVMTYPE_STRING[$3->type]);
      }
    ;


function_definition
    : FUNC IDENTIFIER '(' ')' {
            asmFuncDcl(T_VOID, $2, "");
      } compound_statement  {
            SymbolEntry *entry = new SymbolEntry($2, A_FUNC, T_VOID, &EMPTY_SV, true);
            symTable->insert(entry);
            asmFuncRtnCheck();
      }
    | FUNC type_specifier IDENTIFIER '(' ')' {
            asmFuncDcl($2, $3, "");
      } compound_statement {
            SymbolEntry *entry = new SymbolEntry($3, A_FUNC, T_VOID, &EMPTY_SV, true);
            symTable->insert(entry);
            asmFuncRtnCheck();
      }
    | FUNC type_specifier IDENTIFIER '(' {
            enterScope(false);
      } parameter_list {
              preCreatedSymTable = symTable;
              exitScope(false);
      } ')' {
            asmFuncDcl($2, $3, asmGetParamsString($6));
      } compound_statement  {
            SymbolEntry *entry = new SymbolEntry($3, A_FUNC, $2, &EMPTY_SV, true);
            symTable->insert(entry);
            asmFuncRtnCheck();
      }
    ;
parameter_list
    : parameter_declaration {
            $$.count = 1;
            $$.types[0] = $1->type;
      }
    | parameter_list ',' parameter_declaration {
            $1.types[$1.count++] = $3->type;
            $$ = $1;
      }
    ;
parameter_declaration
    : IDENTIFIER type_specifier {
            $$ = new SymbolEntry($1, A_VAR, $2, &EMPTY_SV, true);
            symTable->insert($$);
      }
    ;


external_declaration
    : function_definition
    | declaration
    ;

program_unit
    : external_declaration
    | program_unit external_declaration
    ;

%%


int main(int argc, char *argv[]) {
    if (argc != 2) {
        cout << "Usage: " << argv[0] << " src_file" << endl;
        exit(-1);
    } else {
        yyin = fopen(argv[1], "r");
        if (!yyin) {
            cout << "Error opening source file." << endl;
            exit(-1);
        }

        className = string(basename(argv[1]));
        className = className.substr(0, className.find("."));
        // cout << className << endl;
    }

    asmAppend("/*-------------------------------------------------*/");
    asmAppend("/*                Java Assembly Code               */");
    asmAppend("/*-------------------------------------------------*/");
    asmAppend("");

    asmAppend("class %s", className.c_str());
    // '{' of class declaration
    asmAppend("{");
    identLevel++;

    enterScope(); // enter "global scope"
    yyparse();
    exitScope(); // exit "global scope"

    // '}' of class declaration
    identLevel--;
    asmAppend("}");

    // Dump all symbol tables & free memory
#ifdef DUMP_SYMTABLE
    dumpSymbolTables();
#endif
    symTablePool.clear();

    // Conbiles all the asm lines
    string asmOutputString = asmGetOutputString();
    // Print the entire asm output
    // cout << endl << asmOutputString;

    // Store the asm into file
    string asmFilename = className + ".jasm";
    fstream fp;
    fp.open(asmFilename, ios::out);
    if (!fp) {
        cout << "Failed to open file: " << asmFilename << endl;
        exit(1);
    } else {
        fp << asmOutputString;
    }
    fp.close();

    cout << endl << "Java Assembly is written to " << asmFilename << ", completed." << endl;

#ifdef EXEC_JAVAA
    cout << endl << "Executing javaa..." << endl;
    ss.str("");
    ss << JAVAA_PATH << " " << asmFilename;
    system(ss.str().c_str());
#endif

    return 0;
}

void dumpSymbolTables() {
    for (int i = 0; i < symTablePool.size(); i++) {
        cout << "\nDumping symbol table " << i << endl;
        symTablePool[i]->dump();
        delete symTablePool[i];
    }
    cout << endl;
}

int yyerror(char *s) {
    fprintf(stderr, "Parsing error: %s\n", s);
    fclose(yyin);
    exit(-1);
}

void enterScope(bool genAsm) {
    if (preCreatedSymTable != NULL) {
        symTable = preCreatedSymTable;
        preCreatedSymTable = NULL;
    } else {
        symTable = new SymbolTable(symTableStack.size());
        symTablePool.push_back(symTable);
    }
    symTableStack.push_back(symTable);

    if (genAsm) {
        // For asm code gen
        if (symTableStack.size() > 1) {
            // When entering scope isn't global scope
            asmAppend("{");
            identLevel++;
        }
    }
}

void exitScope(bool genAsm) {
    symTableStack.pop_back();

    if (parsingCompoundBranch) {
        preCreatedSymTable = NULL;
    }

    if (genAsm) {
        // For asm code gen
        if (symTableStack.size() > 0) {
            // When exiting scope isn't global scope
            identLevel--;
            asmAppend("}");
        }
    }

    if (!symTableStack.empty())
        symTable = symTableStack.back();
    else
        symTable = NULL;
}

SymbolEntry* constDcl(char *ident, SymbolEntry *constExpr) {
    strcpy(constExpr->ident, ident);
    return constExpr;
}

SymbolEntry* varDcl(char *ident, SymbolType type, SymbolEntry *constExpr) {
    strcpy(constExpr->ident, ident);

    // Implicit type conversion
    if (type == T_REAL && constExpr->type == T_INT) {
        constExpr->value.t_double = (double) constExpr->value.t_int;
    }
    
    constExpr->attr = A_VAR;
    constExpr->type = type;
    return constExpr;
}

// Return: pair<symTableStackIndex, indexAtTable> or <-1, *> if not found
pair<int, int> findSymbol(char *ident) {
    int indexAtTable;

    for (int i = symTableStack.size() - 1; i >= 0; i--) {
        SymbolTable *table = symTableStack[i];
        if (-1 != (indexAtTable = table->lookup(string(ident)))) {
            // Symbol found
            return make_pair(i, indexAtTable);
        }
    }
    return make_pair(-1, -1);
}
