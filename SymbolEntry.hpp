#ifndef SYMBOLENTRY_HPP_INCLUDED
#define SYMBOLENTRY_HPP_INCLUDED

#include <string>
#include <cstring>
#include <string>
#include <utility>
#include <sstream>
#include "y.tab.hpp"
#include "types.hpp"

using namespace std;

typedef YYSTYPE SymbolValue;

class SymbolEntry {
public:
    char ident[150];
    SymbolAttr attr;
    SymbolType type;
    SymbolValue value;
    bool is_array = false;
    bool is_nil = true;

    // 4 params
    SymbolEntry(SymbolAttr _attr, int _type, void *_value, bool isNil) :
        attr(_attr), type((SymbolType) _type), is_nil(isNil) {
            if (!isNil)
                memcpy(&value, _value, sizeof(SymbolValue));
        }

    // 5 params
    SymbolEntry(char *_ident, SymbolAttr _attr, int _type, void *_value, bool isNil) :
        attr(_attr), type((SymbolType) _type), is_nil(isNil) {
            strcpy(ident, _ident);
            if (!isNil)
                memcpy(&value, _value, sizeof(SymbolValue));
        }

    // 6 params
    SymbolEntry(char *_ident, SymbolAttr _attr, int _type, void *_value, bool _isArray, bool isNil) :
        attr(_attr), type((SymbolType) _type), is_array(_isArray), is_nil(isNil) {
            strcpy(ident, _ident);
            if (!isNil)
                memcpy(&value, _value, sizeof(SymbolValue));
        }

    string getValueString() {
        switch (this->type) {
            case T_STRING:
                return this->evalVal(string(this->value.t_str));
                break;

            case T_INT:
                return this->evalVal(num2string(this->value.t_int));
                break;

            case T_BOOL:
                return this->evalVal(num2string(this->value.t_int));
                break;

            case T_REAL:
                return this->evalVal(num2string(this->value.t_double));
                break;

            case T_VOID:
                return "N/A";
                break;

            default:
                return string("@") + this->evalVal(num2string(this->value.t_int));
        }
    }

private:
    template <typename T>
    string num2string(const T num) const {
        stringstream ss;
        ss << num;
        return ss.str();
    }

    string evalVal(string str) const {
        if (this->attr == A_FUNC)
            return "N/A";
        else
            return this->is_nil ? "NIL" : str;
    }
};


#endif /* !SYMBOLENTRY_HPP_INCLUDED  */
