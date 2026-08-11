; Treat Java strings rooted at <html> as embedded HTML. Capturing the fragment
; excludes Java's quote/text-block delimiters from the virtual HTML document.
((string_literal
  (string_fragment) @injection.content)
 (#match? @injection.content "<html>")
 (#set! injection.language "html"))

((string_literal
  (multiline_string_fragment) @injection.content)
 (#match? @injection.content "<html>")
 (#set! injection.language "html"))
