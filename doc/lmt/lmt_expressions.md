# Lmt Regular Expressions

Our Lmt language depends is a regular language and depends on a few regular expressions, we are listing them here because both the tangler and weave care about them.

## The Include Expression

The first regular expression handles the detection of include directives.  It recognizes lines like `! include [some description](some-file)`  and extracts `some-file`.

###### Code Block: Include Expression

``` ruby
/^!\s+include\s+\[.*\]\((.*)\)\s*$/
```

## The Code Block Expression

The second regular expression is intended to note when whe enter or leave a code block.  It detects markdown code fences and processes the special directives.  It has four groups.  The first identifies white space at the beginning of the line.  The second detects the language.  The third determines if this is a replacement.  The fourth is the name of the block (if applicable).

###### Code Block: Code Block Expression

``` ruby
/^([s]*)``` ?([\w]*) ?(=?)([-\w]*)?/
```

## The Macro Substitution Expression

The third expression identifies macro expansions surrounded with `⦅` and `⦆`.  The first bit deals with making sure that the opening `⦅` isn't escaped.  Then there is one group which contains the name of the macro combined and any filters which are being used.

###### Code Block: Macro Substitution Expression

``` ruby
/(?<!\\)⦅ *([-\w | ]*) *⦆/
```
