# simple-go-jasm-compiler
This is the final project of NTUST CS3020301 Compiler Design, which generates code (in Java assembly language) for the Go- language.
The generated code will then be translated to Java bytecode ``*.class`` by a Java assembler ``javaa``.  
For detailed description, please see ``proj1.pdf`` ~  ``proj3.pdf`` in ``/assignments``.  

## Run
**Compile project and javaaPortable sources**  
```
make clean
make all
```

**Generate Java assembly**  
There are some sample Go- source code in /go_source for testing.  
For example, ``/go_sources/fib.go.txt``  
```
./sgoc go_sources/fib.go.txt
```
Then ``fib.jasm`` and ``fib.class`` is now generated.  

**Run Java assembly with JVM**
```
java fib
```
