# Shuttle specification build recipes
# Requires: pandoc, just

# Build the spec to index.html
build:
    pandoc spec.md -o index.html --template=template.html --standalone

# Build and open in browser
preview: build
    open index.html

# Remove generated files
clean:
    rm -f index.html
