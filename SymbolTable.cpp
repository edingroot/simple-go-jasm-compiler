#include "SymbolTable.hpp"
#include "SymbolEntry.hpp"
#include <map>
#include <string>
#include <iostream>

using namespace std;


SymbolTable::SymbolTable(int _level) : level(_level) {
    this->table = new map<string, pair<int, SymbolEntry*> >();
}

int SymbolTable::lookup(const string& s) const {
    map<string, pair<int, SymbolEntry*> >::iterator iter = this->table->find(s);

    if (iter != this->table->end()) {
        return iter->second.first;
    } else {
        return -1;
    }
}

SymbolEntry* SymbolTable::get(const string& s) const {
    map<string, pair<int, SymbolEntry*> >::iterator iter = this->table->find(s);

    if (iter != this->table->end()) {
        return iter->second.second;
    } else {
        return NULL;
    }
}

int SymbolTable::insert(SymbolEntry *entry) {
    int newIndex = this->table->size();
    pair<string, pair<int, SymbolEntry*> > mapEntry = make_pair(entry->ident, make_pair(newIndex, entry));
    bool success = this->table->insert(mapEntry).second;
    return success ? newIndex : -1;
}

void SymbolTable::dump() const {
    map<string, pair<int, SymbolEntry*> >::iterator iter;

    cout << "-table level: " << this->level << endl;
    if (!this->table->empty()) {
        cout << "Index\tIdentifier\tAttr\tType" << endl;
        for (iter = this->table->begin(); iter != this->table->end(); iter++) {
            int index = iter->second.first;
            SymbolEntry *entry = iter->second.second;

            cout << index << "\t" << entry->ident << "\t\t" << ATTR_STRING[entry->attr] << "\t";
            cout << TYPE_STRING[entry->type] << endl;
        }
    } else {
        cout << "-this table is empty.\n";
    }
}

SymbolTable::~SymbolTable() {
    map<string, pair<int, SymbolEntry*> >::iterator iter;
    for (iter = this->table->begin(); iter != this->table->end(); iter++) {
        delete iter->second.second;
    }
    delete this->table;
}
