# Shuttle

Shuttle is an S-expression based markup language that can be transformed to and from HTML.

## Quick Example

```lisp
(html lang=en
  (head (title My Page))
  (body
    (h1 Hello World)
    (p This is Shuttle.)))
```

## Specification Generation

Requires [just](https://github.com/casey/just) and [pandoc](https://pandoc.org/).

```sh
just build      # Build spec to index.html
just preview    # Build and open in browser
just clean      # Remove generated files
```