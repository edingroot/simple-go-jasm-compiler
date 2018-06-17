#ifndef ASMUTIL_HPP_INCLUDED
#define ASMUTIL_HPP_INCLUDED

#include <sstream>
#include <vector>

extern vector<SymbolTable*> symTableStack;
extern string className;
extern int yyerror(char *s);

const int TAB_SPACES = 2;

vector<string> asmOutputs;
int identLevel = 0;

SymbolType lastFuncRtnType;
bool asmRtnAppended = false;
bool parsingCompoundBranch = false;
int asmLastVarLoaded = -1;
int asmLastConstLoaded = -1;

struct {
    int n_logic = 0;
    int n_if = 0;
    int n_for = 0;
} asmTagCounter;

// For asm generation related functions
char asmLineBuf[150];
va_list args;
stringstream ss;

void asmAppend(const char *format, ...) {
    asmLineBuf[0] = '\0';
    va_start(args, format);
    vsprintf(asmLineBuf, format, args);
    va_end(args);

    ss.str("");
    ss << string(identLevel * TAB_SPACES, ' ') << asmLineBuf << endl;
    asmOutputs.push_back(ss.str());

#ifdef ASM_REALTIME_PRINT
    cout << ss.str();
#endif
}

void asmAppendAtLine(int lineIdentLevel, int lineIndex, const char *format, ...) {
    asmLineBuf[0] = '\0';
    va_start(args, format);
    vsprintf(asmLineBuf, format, args);
    va_end(args);
    
    ss.str("");
    ss << string(lineIdentLevel * TAB_SPACES, ' ') << asmLineBuf << endl;
    asmOutputs.insert(asmOutputs.begin() + lineIndex, ss.str());

#ifdef ASM_REALTIME_PRINT
    cout << ss.str();
#endif
}

void asmAppendTag(const string &tagName, int number = -1) {
    ss.str("");
    ss << tagName;
    if (number != -1)
        ss << number;
    ss << ":" << endl;
    asmOutputs.push_back(ss.str());

#ifdef ASM_REALTIME_PRINT
    cout << ss.str();
#endif
}

inline void asmTrimLines(int beginIndex, int count) {
#ifdef ASM_REALTIME_PRINT
    cout << "@ASM: Skip line " << beginIndex << " to "<< beginIndex + count - 1 << "." << endl;
#endif
    int endIndex = beginIndex + count;
    if (beginIndex >= asmOutputs.size()) {
        cout << "@ASM: [Warning] asmTrimLines: indexes out of bound." << endl;
        return;
    }
    if (endIndex > asmOutputs.size()) {
        cout << "@ASM: [Warning] asmTrimLines: indexes out of bound." << endl;
        endIndex = asmOutputs.size() - 1;
    }
    asmOutputs.erase(asmOutputs.begin() + beginIndex, asmOutputs.begin() + endIndex);
}

// Conbiles all the asm lines
string asmGetOutputString() {
    stringstream asmOutputStream;

    for (int i = 0; i < asmOutputs.size(); i++) {
        asmOutputStream << asmOutputs[i];
    }
    return asmOutputStream.str();
}

string asmGetParamsString(const SymbolTypeList &typeList) {
    string paramStr = "";
    for (int i = 0; i < typeList.count; i++) {
        paramStr += JVMTYPE_STRING[typeList.types[i]] + string(",");
    }
    return paramStr.substr(0, paramStr.length() - 1);
}

void asmVarDcl(SymbolEntry *entry, int indexAtTable = -1) {
    if (symTableStack.size() == 1) { // Global variable
        // Remove asm push constant ops
        if (asmLastConstLoaded != -1) {
            asmTrimLines(asmLastConstLoaded, 1);
            asmLastConstLoaded = -1;
        }

        if (entry->is_nil) {
            asmAppend("field static %s %s", JVMTYPE_STRING[entry->type], entry->ident);
        } else {
            asmAppend("field static %s %s = %d", JVMTYPE_STRING[entry->type], entry->ident, entry->value.t_int);
        }
    } else {
        // Local variable
        int ivalue = entry->is_nil ? 0 : entry->value.t_int;
        asmAppend("istore %d", indexAtTable);
    }
}

void asmFuncDcl(SymbolType symType, char *ident, const string &paramString) {
    lastFuncRtnType = symType;
    asmRtnAppended = false;

    asmAppend("");
    if (string(ident) == "main")
        asmAppend("method public static void main(java.lang.String[])");
    else
        asmAppend("method public static %s %s(%s)", JVMTYPE_STRING[symType], ident, paramString.c_str());
    asmAppend("max_stack 15");
    asmAppend("max_locals 15");
}

void asmFuncRtn() {
    switch (lastFuncRtnType) {
        case T_INT:
        case T_BOOL:
            asmAppend("ireturn");
            break;

        case T_REAL:
            asmAppend("dreturn");
            break;

        case T_VOID:
            asmAppend("return");
            break;

        default:
            yyerror("Function return type not supported.");
    }
    asmRtnAppended = true;
}

// If function return statement not stated in source code, add it here manually
void asmFuncRtnCheck() {
    if (!asmRtnAppended) {
        asmAppendAtLine(identLevel + 1, asmOutputs.size() - 1, "return");
    }
}

void asmGoto(const string &tagName, int number = -1) {
    ss.str("");
    ss << "goto " << tagName;
    if (number != -1)
        ss << number;
    asmAppend(ss.str().c_str());
}

void asmRelOp(const string &relOp, const string &tagName, int number = -1) {
    ss.str("");
    ss << relOp << " " << tagName;
    if (number != -1)
        ss << number;
    asmAppend(ss.str().c_str());
}

void asmLogicOp(const string &opAsm) {
    asmAppend("isub");
    asmRelOp(opAsm, "Ltrue", asmTagCounter.n_logic);
    asmAppend("iconst_0");
    asmGoto("Lfalse", asmTagCounter.n_logic);
    asmAppendTag("Ltrue", asmTagCounter.n_logic);
    asmAppend("iconst_1");
    asmAppendTag("Lfalse", asmTagCounter.n_logic);
    asmTagCounter.n_logic++;
}


string escapeString(const string& input) {
    ostringstream ss;
    for (string::const_iterator iter = input.begin(); iter != input.end(); iter++) {
        switch (*iter) {
            case '\\': ss << "\\\\"; break;
            case '"': ss << "\\\""; break;
            case '/': ss << "\\/"; break;
            case '\b': ss << "\\b"; break;
            case '\f': ss << "\\f"; break;
            case '\n': ss << "\\n"; break;
            case '\r': ss << "\\r"; break;
            case '\t': ss << "\\t"; break;
            default: ss << *iter; break;
        }
    }
    return ss.str();
}


#endif /* !ASMUTIL_HPP_INCLUDED  */
