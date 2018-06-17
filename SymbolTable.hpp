#ifndef SYMBOLTABLE_HPP_INCLUDED
#define SYMBOLTABLE_HPP_INCLUDED

#include <string>
#include <map>
#include <utility>
#include "y.tab.hpp"
#include "SymbolEntry.hpp"

using namespace std;


class SymbolTable {
public:
	SymbolTable(int _level);

	/**
	 * Symbol table entry lookup.
	 * Return: index(serial number) of the entry or -1 if not found.
	 */
	int lookup(const string& s) const;

	/**
	 * Get pointer to a symbol entry by identifier.
	 * Return: SymbolEntry* or NULL if not found.
	 */
	SymbolEntry* get(const string& s) const;

	/**
	 * Insert a new table entry (override if entry with same identifier existed).
	 * Return: Index of inserted entry or -1 if failed.
	 */
	int insert(SymbolEntry *entry);

	/**
	 * Dump the symbol table entries and its contents via stdout.
	 */
	void dump() const;

	/**
	 * Release all used resources.
	 */
	~SymbolTable();

private:
	int level;
	map<string, pair<int, SymbolEntry*> > *table; // <ident, pair<index, SymbolEntry*>>

	string evalVal(SymbolEntry *entry, string val) const;

	// In MinGW std::to_string() does not exist
	template <typename T>
	string num2string(const T num) const;

};


#endif /* !SYMBOLTABLE_HPP_INCLUDED  */
