# Lmt Regular Expressions

Our Lmt language depends is a regular language and depends on a few regular expressions, we are listing them here because both the tangler and weave care about them.

## The Include Expression

The first regular expression handles the detection of include directives.  It recognizes lines like `! include [some description](some-file)`  and extracts `some-file`.

###### Code Block: Include Expression

``` ruby
/^!\s+include\s+\[.*\]\((.*)\)\s*$/
```

## The Include Path Expression

This regular expression handles the detection of include-path directives.  It recognizes lines like `! include-path some-path`  and extracts `some-path`.

###### Code Block: Include Path Expression

``` ruby
/^!\s+include-path\s+(.*)\s*$/
```

## The Block Expressions

These regular expression recognize if, elseif, else, and end directives.  The first group contains the conditional for blocks that have a conditional..

###### Code Block: If Expression

``` ruby
/^!\s+if\s+(.*)$/
```

###### Code Block: Else Expression

``` ruby
/^!\s+else/
```

###### Code Block: Elsif Expression

``` ruby
/^!\s+elsif\s+(.*)$/
```

###### Code Block: End Expression

``` ruby
/^!\s+end$/
```

## The Code Block Expression

This expression is intended to note when whe enter or leave a code block.  It detects markdown code fences and processes the special directives.  It has four groups.  The first identifies white space at the beginning of the line.  The second detects the language.  The third determines if this is a replacement.  The fourth is the name of the block (if applicable).

###### Code Block: Code Block Expression

``` ruby
/^(\s*)``` ?([\w]*) ?(=?)([-\w]*)?/
```

## The Extension Expression

This expression identifies blocks of code which are to be executed.  The first group identifies white space at the beginning of the line.

###### Code Block: Extension Expression

``` ruby
/^(\s*)``` ruby !/
```

## The Macro Substitution Expression

This identifies macro expansions surrounded with `⦅` and `⦆`.  The first bit deals with making sure that the opening `⦅` isn't escaped.  Then there is one group which contains the name of the macro combined and any filters which are being used.

###### Code Block: Macro Substitution Expression

``` ruby
/(?<!\\)⦅ *([-\w | ]*) *⦆/
```
