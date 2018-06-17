#ifndef TYPES_HPP_INCLUDED
#define TYPES_HPP_INCLUDED

/*
 - const char* const: avoid duplicate symbol error while linking object files
   Ref: https://stackoverflow.com/questions/29739510/makefile-duplicate-symbol
*/

typedef enum {
	A_NA,
	A_IDENT,
	A_CONST,
	A_VAR,
	A_FUNC
} SymbolAttr;
const char* const ATTR_STRING[] = {"N/A", "ident", "const", "var", "func"};

typedef enum {
	T_VOID,
	T_STRUCT,
	T_STRING,
	T_INT,
	T_REAL,
	T_BOOL
} SymbolType;
const char* const TYPE_STRING[] = {"void", "struct", "string", "int", "real", "bool"};
const char* const JVMTYPE_STRING[] = {"void", "struct", "java.lang.String", "int", "double", "boolean"};

typedef struct {
	int count;
	SymbolType types[50];
} SymbolTypeList;


#endif /* !TYPES_HPP_INCLUDED  */
