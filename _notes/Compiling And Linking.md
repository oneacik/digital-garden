---
---

![Avocado](../assets/interlinked.png)


## Introduction

C, C++, Rust, Swift and all binary libraries can cooperate with each other.  
The foundation of this cooperation lies in ABI which is common Application Binary Interface.  
This post will explain how to use common ABI, to call code between languages.  
It will cover C and C++ as the rest should be quite similar.  
But first we need to understand how exactly code is compilled and then linked.

## Compilation

Compilation is an act of translating readable code into machine code.  
However, during this process we also emit symbols so our machine code can be called from another module.  
Let's see compilation in action of this sample C code:

```c

// code.c
inf func(int a) {
    return a*2;
}
```

After compiling it using `gcc -c code.c`, we get code.o file which is intermediate object -  
it contains symbols AKA functions, variables and other useful things.

Using `objdump -t code.o` we can see what meaningful symbols does it contain:

```
➜  temp objdump -t code.o  

code.o:     file format elf64-x86-64

SYMBOL TABLE:
...different symbols...
0000000000000000 g     F .text	000000000000000e func
```

It has a symbol representing 'func' in it.  
It doesn't represent what types it consumes or returns:

- It just informs you that it is stored at 0x00 relative address.
- Is a (g)lobal (F)unction stored in .text section
- It has size of 0x0b bytes
- And is named func

Let's create another file that will consume this obj file.  
(As this code doesn't have main, we can't compile it into executable yet.)

```c
int func();

int main(){
  return func();
}
```

Let's use again our objdump after compilation.

```
➜  temp objdump -t main.o 

main.o:     file format elf64-x86-64

SYMBOL TABLE:
...spam...
0000000000000000 g     F .text	0000000000000010 main
0000000000000000         *UND*	0000000000000000 func
```

We can see that func is *UND*efined, because it needs to be linked.  
We will do it in the next step.

Now we can just link those files and hello the shit out of the world.  
Or can't we?

## Linking

is a process of merging all object files together.  
There are also some special steps if we want to make an executable file or library,  
however we can skip them for later.

Let's link our object files into one large object file.
```
gcc -o main code.o main.o
```

Dump our output file:

```
➜  temp objdump -t main

main:     file format elf64-x86-64

SYMBOL TABLE:
...a lot more spam...
0000000000401116 g     F .text	000000000000000e              func
0000000000401106 g     F .text	0000000000000010              main
...Fun Fact: real entrypoint in an elf file...
0000000000401020 g     F .text	000000000000002f              _start
```

You can see that undefined and defined 'func' definition **merged into the defined function**.

And finally run the code!
```
➜  ./main                   
➜  echo $?
2
```
Ok, well, so we got returned 2 as exit code. But why, wait, aha, ok.  
So where was our argument, why there wasn't any compilation error, wtf?

Here files are compiled separately and each seems to be ok for itself.  
However, during linking we get horrible errors.

How to avoid problems like this?

## Header files

are just files to avoid duplication. They don't have any magic, they don't bite.  
Using '#include' directive you just paste it into .c files.  
They are never compiled, you should just compile .c files.

When you include .h file and define function, then it will overriden with defined function.  
If you include .h file and define function with typo then code won't compile to executable,  
as the not typo'ed function won't be found anywhere and will be undefined.

When you include .h file in consuming .c file, it will be undefined till linking -  
However you will be able to use this code in your files.

```c
// code.h
int func(int a);
// code.c
#include "code.h"

int func(int a) {
    return a*2;
}
// main.c
#include "code.h"

int main(){
  return func();
}
```

Now compiler can see that definitions do not match.

```
➜  temp gcc main.c
main.c: In function ‘main’:
main.c:4:10: error: too few arguments to function ‘func’
    4 |   return func();
      |          ^~~~
In file included from main.c:1:
code.h:1:5: note: declared here
    1 | int func(int a);
      |     ^~~~
```

Header files just put us on the common ground.

Finally, let's see correct main.c in action:

```c
#include "code.h"

int main(){
  return func(64);
}
```

And the result:
```
➜  gcc -o main main.c code.c
➜  ./main                   
➜  echo $?                  
128 
```

## C++ compilation - mangling

Ok, but let's assume that one of our files is written in C++.  
Let it be main.c, let's compile it using g++ and dump contents:
```
➜  g++ -c code.c
➜  objdump -t code.o 

code.o:     file format elf64-x86-64

SYMBOL TABLE:
...this time with spam...
0000000000000000 l    df *ABS*	0000000000000000 code.c
0000000000000000 l    d  .text	0000000000000000 .text
0000000000000000 l    d  .data	0000000000000000 .data
0000000000000000 l    d  .bss	0000000000000000 .bss
0000000000000000 l    d  .note.GNU-stack	0000000000000000 .note.GNU-stack
0000000000000000 l    d  .eh_frame	0000000000000000 .eh_frame
0000000000000000 l    d  .comment	0000000000000000 .comment
0000000000000000 g     F .text	000000000000000e _Z4funci
```

Try to find our func, look carefully, yes here it is!:
```
0000000000000000 g     F .text	000000000000000e _Z4funci
```

You can see our [mangled function](https://stackoverflow.com/questions/41524956/gcc-c-name-mangling-reference).  
Omitting '_Z' prefix we see four letter function "func" with (i)nteger argument.  
It is the mechanism allowing C++ to provide function overload -  
i.e. many same named functions with different types.  
You can notice that there isn't anything about return type, that's sad -  
we can't have in C++ same function with different return types.

So how can we use this function in our main.c file?  
Either mark it extern "C" like a virgin:

```c
// code.h
#ifdef __cplusplus
extern "C" {
#endif
int func(int a);
#ifdef __cplusplus
}
#endif
// code.c
#include "code.h"

int func(int a) {
    return a*2;
}
// main.c
#include "code.h"

int main(){
  return func();
}
```

and lose ability to call already compiled C++ libraries.  
Or call it by its FULL NAME, like a real CHAD.

```c
// code.h
#ifdef __cplusplus
int func(int a);
#else
int _Z4funci(int a);
#endif
// main.c
#include "code.h"

int main(){
  return _Z4funci(64);
}
// code.c
#include "code.h"

int func(int a) {
    return a*2;
}
```

I'm not even sure if the last example is compatible with other compilers, but it is cool, isn't it? Come on.

## Summary

So now you see that compilation is just an act of emitting symbols we want and those we give.  
There is nothing scary in object files -  
cooperability with other languages is just naming those symbols properly.  

Now go to different platforms like Windows, Linux, Darwin, Arm, STM32.  
Is it all in linking though?

## Fun Fact - Linker scripts

Let's enumerate some binary formats:
- elf
- exe
- bin (for microcontrollers)

And for controllers, even if they use ARM architecture, we always need a different toolchain.  
Why is that?  

And here comes into play linker script.  
Elf32 format is also defined by linker script.  
You can see it by using `ld --verbose` command:

```
➜  ld --verbose
using internal linker script:
==================================================
/* Script for -z combreloc -z separate-code */
/* Copyright (C) 2014-2020 Free Software Foundation, Inc.
   Copying and distribution of this script, with or without modification,
   are permitted in any medium without royalty provided the copyright
   notice and this notice are preserved.  */
OUTPUT_FORMAT("elf64-x86-64", "elf64-x86-64",
	      "elf64-x86-64")
OUTPUT_ARCH(i386:x86-64)
ENTRY(_start) /* About that _start  */
SEARCH_DIR("=/usr/x86_64-redhat-linux/lib64"); SEARCH_DIR("=/usr/lib64"); SEARCH_DIR("=/usr/local/lib64"); SEARCH_DIR("=/lib64"); SEARCH_DIR("=/usr/x86_64-redhat-linux/lib"); SEARCH_DIR("=/usr/local/lib"); SEARCH_DIR("=/lib"); SEARCH_DIR("=/usr/lib");
SECTIONS
{
...many more lines...
```

This will define how should the data from compiled binary file be loaded into memory later.  
It is quite important for microcontrollers where interruption vectors must be given correct values.  
And different toolchains give different linker scripts and libraries for different devices.

Just to mark, elf file is not defined by this script, but it contents are.  
You can't create a wav file using nice linker script with correct symbols,  
unless you have a funny binary format.

I hope it was an interesting journey.  
Good Luck.