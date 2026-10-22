# Design

This document owns the visual appearance of the product: the tokens, the
component vocabulary built on them, and the states every component renders.
It is fixed before the first screen and extended in the same change set
that adds a token or a component (`docs/ARCHITECTURE_PRINCIPLES.md`
§"Design system"). What the product *does* lives in `docs/SPEC.md`; how it
is built lives in `docs/ARCHITECTURE.md`.

## Principles

*(The three to five statements that decide close calls: what the product
should feel like, what it never does, which platform conventions it follows
and which it deliberately overrides.)*

## Tokens

*(One subsection each. Every value the interface uses is listed here by
name; a literal in a screen or a component is a defect.)*

### Colour

### Typography

### Spacing

### Shape

### Elevation

### Motion

## Components

*(One subsection per component: its role, the tokens it reads, its variants,
its states — loading, empty, error, disabled, pressed — each of which it
renders, and its accessibility contract — accessible name and role, focus
behaviour, the contrast pairs it is checked against, how it scales with the
platform's text size. The library implements exactly this list; a component
in the library that is not here, or here that is not in the library, is a
defect.)*

## Screens

*(One line per screen naming the components it composes. A screen listed
with a component that does not exist above is the signal that the component
has to be designed first.)*
