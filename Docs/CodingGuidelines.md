# SnekStudio Coding Guidelines

NOTE: As of this writing, SnekStudio code is very messy, and these
guidelines are coming far too late. Please apply this to code written
going forward from here.

Also (optionally) any time a significant enough change is done to a
piece of code, you can update it if you want. For example, adding a
parameter to a function might be a good excuse to define the variable
types if it doesn't already have them.

SnekStudio is a product that grew gradually and organically out of
Kiri's VTuber needs, and the structure admittedly shows that. Code
quality improvement is an ongoing task.

## Function and Variable Definitions

Please use the [double-hash-symbol
comments](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html#documenting-script-members)
to describe any function or variable expected to be called or used
from outside of a given class. For internal class functions and
variables this is optional but still encouraged.

Internal class functions and variables must start with and underscore
(`_`) to differentiate between them and "public" functions.

All variable types, parameter types and return types must be
specified. For example:

Bad:
```
func foo(bar):
    ...
```

Good:
```
func foo(bar : String) -> void:
    ...
```

`Variant` types are an exception to this. If a variable must be a
Variant, then specifying `Variant` as a type is optional.

## Trailing Whitespace

Please try to clean up any trailing whitespace (including on empty
lines).
