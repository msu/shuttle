---
title: "Shuttle: An S-expression Based Markup Language"
author: "Carson Gross (carson@bigsky.software)"
created: "February 14, 2026"
updated: "February 14, 2026"
status: "Living Document"
---

## Introduction

*This section is non-normative.*

HTML uses an [SGML-derived](https://en.wikipedia.org/wiki/Standard_Generalized_Markup_Language) derived
angle-bracket syntax that is verbose and token-heavy. For contexts
where compactness matters, such as LLM token budgets, a more concise notation is desirable.

The Shuttle Hypertext Markup Language (SHML) provides such a notation by adopting
[S-expressions](https://en.wikipedia.org/wiki/S-expression) as its surface
syntax. Every Shuttle expression maps unambiguously to an HTML element,
preserving full fidelity: tag names, attributes, text content, and nesting are
all represented.

A Shuttle document:

```lisp
(div class=container
  (h1 Welcome)
  (p This is Shuttle.))
```

Produces the following HTML:

```html
<div class="container">
  <h1>Welcome</h1>
  <p>This is Shuttle.</p>
</div>
```

For the [gpt-4o](https://en.wikipedia.org/wiki/GPT-4o) tokenizer the above HTML creates 27 tokens, whereas the SHML 
produces 19 tokens, a 29.6% reduction in token count.

### Design Goals

Shuttle is designed with the following goals:

1. Minimal syntax: the fewest possible metacharacters and rules.
2. Unambiguous parsing: every valid input has exactly one parse tree.
3. Lossless mapping: round-trip fidelity to HTML serialization.
4. Human readability: natural to read and write for anyone familiar with HTML.

### Scope

This specification defines the surface syntax of the Shuttle language and its
mapping to HTML serialization. It does not define a Document Object Model,
rendering behavior, or processing model beyond parsing and serialization.

## Conformance

The keywords "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
"SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be
interpreted as described in [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

## Terminology

The following terms are used throughout this specification:

**Shuttle document**
:   A Unicode string conforming to the grammar defined in this specification.

**Element**
:   A tagged S-expression consisting of a tag name, zero or more properties,
    and zero or more content items.

**Tag name**
:   A name identifying the type of an element.

**Property**
:   A name-value pair associated with an element, corresponding to an HTML
    attribute.

**Property name**
:   A name identifying a property.

**Property value**
:   A string value associated with a property name.

**Boolean property**
:   A property with no value, indicated by a trailing `=` with nothing
    following before the next whitespace or `)`.

**Empty string property**
:   A property whose value is the empty string, indicated by `=""`.

**Content item**
:   A text string or child element within an element, following the properties.

**Text content**
:   A run of characters within the content of an element that is not a nested
    element.

**Shuttle processor**
:   A conforming implementation that parses Shuttle documents and produces
    serialized output.

**Parse error**
:   A condition where the input does not conform to the grammar defined in this
    specification.

**Whitespace**
:   Any of the following Unicode code points: U+0020 SPACE, U+0009 TAB,
    U+000A LINE FEED, U+000D CARRIAGE RETURN.

**Void element**
:   An HTML element that cannot have content. The void elements are: `area`,
    `base`, `br`, `col`, `embed`, `hr`, `img`, `input`, `link`, `meta`,
    `source`, `track`, `wbr`.

## Syntax

### Character Set

A Shuttle document is a sequence of Unicode code points.

Whitespace characters serve as delimiters between tokens. The recognized
whitespace characters are U+0020 SPACE, U+0009 TAB, U+000A LINE FEED, and
U+000D CARRIAGE RETURN.

### Formal Grammar

The following ABNF grammar ([RFC 5234](https://www.rfc-editor.org/rfc/rfc5234))
defines the syntax of a Shuttle document.

```abnf
document        = *( WS / comment / element / text-content )

element         = "(" *WS tag-name *( 1*WS property ) content ")"

tag-name        = name-start-char *name-char

property        = property-name "=" property-value
                / property-name "=" DQUOTE DQUOTE       ; empty string
                / property-name "="                      ; boolean

property-name   = name-start-char *name-char

property-value  = quoted-value / unquoted-value

quoted-value    = DQUOTE *quoted-char DQUOTE

quoted-char     = unescaped-quoted / entity-reference

unescaped-quoted = %x20-21 / %x23-25 / %x27-7E
                 ; visible ASCII + space, excluding " and &

unquoted-value  = 1*unquoted-char

unquoted-char   = %x21-27 / %x2A-3B / %x3D / %x3F-7E
                ; visible ASCII excluding ( ) SPACE &

content         = *( 1*WS ( element / text-segment ) )

text-segment    = 1*( text-char / entity-reference / element )

text-char       = %x21-25 / %x27 / %x2A-3B / %x3D-7E / WS
                ; any printable char or whitespace, excluding ( ) &

entity-reference = "&" 1*( ALPHA / DIGIT / "#" ) ";"

comment         = "(!" comment-text "!)"

comment-text    = *comment-char

comment-char    = %x00-20 / %x22-10FFFF
                ; any character except "!", or
                / %x21 %x00-28 / %x21 %x2A-10FFFF
                ; "!" not followed by ")"

name-start-char = ALPHA / "_"

name-char       = ALPHA / DIGIT / "_" / "-" / "." / ":"

WS              = %x20 / %x09 / %x0A / %x0D
```

Note: The `comment-char` production informally means "any character sequence
that does not contain `!)`". Comments do not nest, mirroring the behavior of
HTML comments.

### Elements

An element is an S-expression delimited by parentheses. It begins with a tag
name, followed by zero or more properties, followed by zero or more content
items.

To **parse an element** from an input stream:

1. Assert: the current input character is U+0028 LEFT PARENTHESIS.
2. Consume the U+0028 LEFT PARENTHESIS.
3. Skip any whitespace.
4. Let *tagName* be the result of consuming a name.
5. If *tagName* is empty, this is a parse error; return failure.
6. Let *properties* be an empty ordered list.
7. Let *children* be an empty ordered list.
8. In a loop:
    1. Skip any whitespace.
    2. If the current input character is U+0029 RIGHT PARENTHESIS, consume it
       and return a new element with tag name *tagName*, properties
       *properties*, and content *children*.
    3. If the current input character is U+0028 LEFT PARENTHESIS, let *child*
       be the result of parsing an element. Append *child* to *children*.
    4. Otherwise, if *children* is empty and the next tokens match the
       `property` production, let *prop* be the result of parsing a property.
       Append *prop* to *properties*.
    5. Otherwise, let *text* be the result of consuming text content. Append
       *text* to *children*.

To **consume a name** from an input stream:

1. Let *name* be the empty string.
2. If the current input character is not a `name-start-char`, return *name*.
3. Append the current input character to *name* and advance.
4. While the current input character is a `name-char`, append it to *name* and
   advance.
5. Return *name*.

### Tag Names

A tag name identifies the type of an element. Tag names begin with a letter
(`A-Z`, `a-z`) or underscore (`_`), followed by zero or more letters, digits
(`0-9`), underscores, hyphens (`-`), dots (`.`), or colons (`:`).

As a non-normative convenience, the pattern can be expressed as the regular
expression `[a-zA-Z_][a-zA-Z0-9_\-.:]*`.

Shuttle does not restrict which tag names are valid. Any conforming name is
accepted. The interpretation of tag names (e.g., mapping to known HTML
elements) is the responsibility of the consuming application.

### Properties

Properties appear after the tag name and before any content items within an
element. Each property consists of a property name, the `=` character, and
optionally a property value.

Three forms of properties are defined:

#### Value Property

A property name followed by `=` and a value. The value may be quoted or
unquoted.

**Unquoted values** terminate at the next whitespace, `(`, or `)`.

**Quoted values** are delimited by double quotes (`"`) and may contain spaces,
parentheses, and other characters that would otherwise be significant. Entity
references are expanded within quoted values.

```lisp
(a href=/home Home)
(a href="https://example.com/path?q=1&amp;r=2" Link)
```

#### Boolean Property

A property name followed by `=` with no value before the next whitespace or
`)`. In HTML serialization, this produces a boolean attribute.

```lisp
(input type=checkbox checked=)
```

Produces:

```html
<input type="checkbox" checked>
```

#### Empty String Property

A property name followed by `=""`. This is distinct from a boolean property:
the serialized output includes an explicit empty value.

```lisp
(input value="")
```

Produces:

```html
<input value="">
```

To **parse a property** from an input stream:

1. Let *name* be the result of consuming a name.
2. Assert: the current input character is U+003D EQUALS SIGN.
3. Consume the U+003D EQUALS SIGN.
4. If the current input character is U+0022 QUOTATION MARK:
    1. Consume the U+0022 QUOTATION MARK.
    2. Let *value* be the empty string.
    3. While the current input character is not U+0022 QUOTATION MARK:
        1. If the current input character is U+0026 AMPERSAND, let *ref* be the
           result of consuming an entity reference. Append *ref* to *value*.
        2. Otherwise, append the current input character to *value* and advance.
    4. Consume the closing U+0022 QUOTATION MARK.
    5. Return a new property with property name *name* and property value
       *value*.
5. If the current input character is whitespace or U+0029 RIGHT PARENTHESIS,
   return a new boolean property with property name *name*.
6. Otherwise, let *value* be the empty string. While the current input
   character is not whitespace, U+0028 LEFT PARENTHESIS, or U+0029 RIGHT
   PARENTHESIS:
    1. Append the current input character to *value* and advance.
7. Return a new property with property name *name* and property value *value*.

### Content

Content items comprise all tokens after the last property within an element, up
to the matching `)`. Content may consist of interleaved text content and nested
elements.

To **consume text content** from an input stream:

1. Let *text* be the empty string.
2. While the current input character is not U+0028 LEFT PARENTHESIS, U+0029
   RIGHT PARENTHESIS, or end of input:
    1. If the current input character is U+0026 AMPERSAND, let *ref* be the
       result of consuming an entity reference. Append *ref* to *text*.
    2. Otherwise, append the current input character to *text* and advance.
3. Return *text*.

### Property/Content Disambiguation

A token is parsed as a property if and only if:

1. No content items have yet been encountered in the current element, AND
2. The token matches the `property` production (i.e., it has the form
   `Name=...`).

Once any non-property content is encountered --- whether text content or a
nested element --- all subsequent tokens are treated as content, even if they
syntactically match the `property` production.

> Authors MUST use `&equals;` to escape the equals sign when text content at
> the beginning of an element's content area matches the property production.
> Failure to do so will cause the text to be interpreted as a property.

Without escaping, `x=5` would be parsed as a property:

```lisp
(! WRONG: x is parsed as a property with value "5" !)
(p x=5 is the solution)

(! CORRECT: &equals; prevents property parsing !)
(p x&equals;5 is the solution)
```

The correct form produces:

```html
<p>x=5 is the solution</p>
```

## Escaping and Character References

### Entity References

Shuttle supports HTML named character references and numeric character
references within text content and quoted property values.

The syntax for entity references is:

- **Named**: `&name;` where *name* is a recognized HTML character reference
  name.
- **Numeric (decimal)**: `&#digits;` where *digits* is one or more ASCII
  digits.
- **Numeric (hexadecimal)**: `&#xhexdigits;` where *hexdigits* is one or more
  hexadecimal digits.

The complete set of recognized named references is that defined by the HTML
Standard.

To **consume an entity reference** from an input stream:

1. Assert: the current input character is U+0026 AMPERSAND.
2. Consume the U+0026 AMPERSAND.
3. Let *ref* be the empty string.
4. While the current input character is not U+003B SEMICOLON and is not
   whitespace:
    1. Append the current input character to *ref* and advance.
5. If the current input character is U+003B SEMICOLON, consume it.
6. Resolve *ref* to the corresponding Unicode code point(s) per the HTML
   Standard's named character references table, or as a numeric reference.
7. If *ref* cannot be resolved, this is a parse error. Return the literal
   string `&` concatenated with *ref* concatenated with `;`.
8. Return the resolved character(s).

### Required Escaping

The following characters MUST be escaped in certain contexts:

| Context                | Character                   | Escape      | Reason                          |
|------------------------|-----------------------------|-------------|---------------------------------|
| Start of content area  | `=` preceded by a valid name| `&equals;`  | Would be parsed as a property   |
| Text content           | `(`                         | `&lpar;`    | Would open a child element      |
| Text content           | `)`                         | `&rpar;`    | Would close the current element |
| Text content           | `&`                         | `&amp;`     | Would start an entity reference |
| Quoted property value  | `"`                         | `&quot;`    | Would close the quoted value    |

### Parenthesis Handling in Content

An unescaped U+0028 LEFT PARENTHESIS in text content is interpreted as the
opening of a child element. If the content following the parenthesis does not
form a valid element, this is a parse error.

Authors SHOULD escape literal parentheses in content using `&lpar;` and
`&rpar;`.

## Serialization

This section defines how a parsed Shuttle document is serialized to HTML.

### HTML Serialization

To **serialize to HTML** given an element *el*:

1. Let *output* be the empty string.
2. Append `<` to *output*.
3. Append *el*'s tag name to *output*.
4. For each *prop* in *el*'s properties:
    1. Append U+0020 SPACE to *output*.
    2. Append *prop*'s property name to *output*.
    3. If *prop* is a boolean property, do nothing further for this property.
    4. Otherwise:
        1. Append `="` to *output*.
        2. Append *prop*'s property value, with `"`, `&`, `<`, `>` replaced by
           their character reference forms, to *output*.
        3. Append `"` to *output*.
5. Append `>` to *output*.
6. For each *child* in *el*'s content:
    1. If *child* is an element, append the result of serializing *child* to
       HTML to *output*.
    2. If *child* is text content, append *child* with `&`, `<`, `>` replaced
       by their character reference forms to *output*.
7. If *el*'s tag name is not a void element name:
    1. Append `</` to *output*.
    2. Append *el*'s tag name to *output*.
    3. Append `>` to *output*.
8. Return *output*.

### Void Elements

When serializing to HTML, the following elements MUST NOT have a closing tag:
`area`, `base`, `br`, `col`, `embed`, `hr`, `img`, `input`, `link`, `meta`,
`source`, `track`, `wbr`.

If a void element has content items in the Shuttle source, a conforming Shuttle
processor MUST emit a parse error.

### Property Value Quoting

In the serialized output, property values are ALWAYS quoted with double quotes,
regardless of whether the Shuttle source used quoted or unquoted values.

## Comments

A comment begins with the two-character sequence `(!` and ends with the
two-character sequence `!)`. Everything between these delimiters is ignored
during parsing and produces no output.

Comments may span multiple lines. Comments do not nest: the first `!)`
encountered always closes the comment, mirroring the behavior of HTML comments.

Comments may appear anywhere that whitespace is allowed.

```abnf
comment      = "(!" comment-text "!)"
comment-text = *comment-char
comment-char = ; any character except the sequence "!)"
```

Example:

```lisp
(! This is a comment !)
(div class=main
  (! Navigation section !)
  (nav
    (a href=/ Home)      (!inline comment !)
    (a href=/about About))
  (p Content here))
```

Multiline comment:

```lisp
(!
  This entire block is a comment.
  It can span multiple lines.
!)
(p Hello)
```

## Whitespace Handling

The treatment of whitespace depends on its position within the structure:

1. **Between `(` and the tag name** --- allowed and consumed. Not included in
   output.
2. **Between properties** --- serves as a delimiter and is consumed. Not
   included in output.
3. **Between the last property (or tag name) and the first content item** ---
   serves as a delimiter and is consumed. Not included in output.
4. **Within text content** --- preserved verbatim in the output. This includes
   spaces, tabs, and newlines.
5. **Before the closing `)`** --- if content exists, trailing whitespace is
   part of the text content and is preserved.
6. **Between sibling elements within content** --- preserved as text content.

Shuttle preserves whitespace within content exactly as written. It does not
perform whitespace normalization. Any whitespace collapsing is the
responsibility of the consuming application (e.g., an HTML renderer).

## Error Handling

### Parse Errors

The following conditions constitute a parse error:

1. **Unmatched parenthesis** --- a U+0028 LEFT PARENTHESIS without a matching
   U+0029 RIGHT PARENTHESIS, or vice versa.
2. **Empty element** --- `()` with no tag name.
3. **Invalid tag name** --- a tag name that does not conform to the name
   production.
4. **Invalid property name** --- a property name that does not conform to the
   name production.
5. **Unterminated quoted value** --- a U+0022 QUOTATION MARK that is not closed
   before the end of the element or end of input.
6. **Content in void element** --- when targeting HTML serialization, content
   within a void element.
7. **Invalid entity reference** --- a U+0026 AMPERSAND followed by a sequence
   that does not resolve to a known character reference.
8. **Unterminated comment** --- the sequence `(!` without a matching `!)` before
   end of input.

### Error Recovery

A conforming Shuttle processor MUST report all parse errors.

A conforming Shuttle processor MAY attempt error recovery. When error recovery
is attempted, the behavior is implementation-defined.

*The following recovery strategies are non-normative suggestions:*

- **Unmatched `(`** --- treat remaining input as text content of the nearest
  open element.
- **Empty element `()`** --- skip the expression.
- **Invalid entity reference** --- pass through as literal text.
- **Unterminated quoted value** --- close the value at the next `)` or end of
  input.
- **Unterminated comment** --- treat everything from `(!` to end of input as a
  comment.

## Security Considerations

Shuttle is a syntactic notation and does not define execution semantics.
However, since Shuttle output is HTML, all security considerations that apply to
HTML processing apply to the output of a Shuttle processor.

## Examples

*This section is non-normative.*

### Simple Text Element

```lisp
(p Hello World)
```
```html
<p>Hello World</p>
```

### Element with Properties

```lisp
(a href=/home class=nav Home)
```
```html
<a href="/home" class="nav">Home</a>
```

### Boolean Property

```lisp
(input type=checkbox checked=)
```
```html
<input type="checkbox" checked>
```

### Empty String Property

```lisp
(input value="")
```
```html
<input value="">
```

### Nested Elements

```lisp
(div class=container
  (h1 Title)
  (p First paragraph)
  (p Second paragraph))
```
```html
<div class="container">
  <h1>Title</h1>
  <p>First paragraph</p>
  <p>Second paragraph</p>
</div>
```

### Escaped Content

```lisp
(p x&equals;5 is the solution)
```
```html
<p>x=5 is the solution</p>
```

### Quoted Property Values

```lisp
(div class="my container" Multiple classes)
```
```html
<div class="my container">Multiple classes</div>
```

### Comments

```lisp
(! Page header !)
(header
  (h1 Site Title)   (!main heading !)
  (nav
    (!primary navigation !)
    (a href=/ Home)
    (a href=/about About)))
```
```html
<header>
  <h1>Site Title</h1>
  <nav>
    <a href="/">Home</a>
    <a href="/about">About</a>
  </nav>
</header>
```

### Complete HTML Document

```lisp
(html lang=en
  (head
    (meta charset=utf-8)
    (meta name=viewport content="width=device-width, initial-scale=1")
    (title My Page)
    (link rel=stylesheet href=style.css))
  (body
    (header
      (h1 Welcome to My Page))
    (main
      (article
        (h2 Introduction)
        (p This is a complete HTML page written in Shuttle.)
        (p It demonstrates how Shuttle maps naturally to HTML structure.)))
    (footer
      (p © 2026 Example Corp))))
```
```html
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>My Page</title>
    <link rel="stylesheet" href="style.css">
  </head>
  <body>
    <header>
      <h1>Welcome to My Page</h1>
    </header>
    <main>
      <article>
        <h2>Introduction</h2>
        <p>This is a complete HTML page written in Shuttle.</p>
        <p>It demonstrates how Shuttle maps naturally to HTML structure.</p>
      </article>
    </main>
    <footer>
      <p>&copy; 2026 Example Corp</p>
    </footer>
  </body>
</html>
```

### Comparison Table

| Pattern      | Shuttle                    | HTML                                              |
|--------------|----------------------------|---------------------------------------------------|
| Text element | `(p Hello)`                | `<p>Hello</p>`                                    |
| Attribute    | `(a href=/ Home)`          | `<a href="/">Home</a>`                            |
| Boolean attr | `(input disabled=)`        | `<input disabled>`                                |
| Empty attr   | `(input value="")`         | `<input value="">`                                |
| Void element | `(br)`                     | `<br>`                                            |
| Nesting      | `(ul (li A) (li B))`       | `<ul><li>A</li><li>B</li></ul>`                   |
| Comment      | `(! note !)`               | `<!-- note -->`                                   |
