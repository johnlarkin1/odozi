import React from "react";

/**
 * Parses a string with inline [text](url) links, **bold**, and *italic* markers
 * into React nodes. Also handles &lt; / &gt; HTML entities.
 */
export function renderInlineMarkdown(text: string) {
  // Split on [label](url), **bold**, *italic*, and HTML entity patterns
  // **bold** must come before *italic* in the alternation so ** is matched first
  const tokens = text.split(
    /(\[[^\]]+\]\([^)]+\)|\*\*[^*]+\*\*|\*[^*]+\*|&lt;|&gt;)/g
  );
  return tokens.map((token, i) => {
    // Link: [label](url)
    const linkMatch = token.match(/^\[([^\]]+)\]\(([^)]+)\)$/);
    if (linkMatch) {
      return (
        <a
          key={i}
          href={linkMatch[2]}
          target="_blank"
          rel="noopener noreferrer"
          className="text-accent-teal underline decoration-accent-teal/40 underline-offset-2 transition hover:text-accent-teal/80"
        >
          {linkMatch[1]}
        </a>
      );
    }
    // Bold: **text**
    if (token.startsWith("**") && token.endsWith("**")) {
      return (
        <strong key={i} className="text-star-white font-semibold">
          {token.slice(2, -2)}
        </strong>
      );
    }
    // Italic: *text*
    if (token.startsWith("*") && token.endsWith("*")) {
      return (
        <em key={i} className="text-star-white">
          {token.slice(1, -1)}
        </em>
      );
    }
    // HTML entities
    if (token === "&lt;") return "<";
    if (token === "&gt;") return ">";
    return token;
  });
}
