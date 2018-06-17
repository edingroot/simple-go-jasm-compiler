CC = g++
FLAGS = -w -Wc++11-compat-deprecated-writable-strings

all: parser javaa

parser: lex.yy.o y.tab.o
    $(CC) -o sgoc lex.yy.o y.tab.o SymbolTable.o -ll -ly $(FLAGS)

lex.yy.o: y.tab.o
    flex -o lex.yy.cpp tokenizer.l
    $(CC) -c -g lex.yy.cpp SymbolTable.cpp $(FLAGS)

y.tab.o:
    bison -y -d parser.y -o y.tab.cpp
    $(CC) -c -g y.tab.cpp $(FLAGS)

javaa:
    cd javaaPortable && make

clean:
    cd javaaPortable && make clean
    rm -f *.o lex.yy.* y.tab.* sgoc *.jasm *.class
