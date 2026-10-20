# swipl_htmx_demo
Simple demonstration of using HTMX with SWI Prolog

To see what is does, run the server:

```
swipl-win load.pl
```
and browse to http://localhost:4500/demo

See [here](https://htmx.org/) for details of HTMX.

The look and feel is provided by [Pure CSS](https://purecss.io/)

## SWIF
The demo uses SWIF (SWI Forms) as a wrapper around the low level HTMX to provide a convenient high level interface for forms based applications

SWIF (SWI Forms) is a lightweight web application framework based on:
  $ Pure CSS: https://purecss.io/
  $ PostgreSQL: https://www.postgresql.org/
  $ HTMX: https://htmx.org/
  $ Hyperscript: https://hyperscript.org/
  $ SWI Prolog: https://www.swi-prolog.org/

This framework is intended for the rapid
development of form-oriented web applications using the good looks of
Pure CSS, the platform independence of PostgreSQL, the
hypertext-for-everything capabilities of HTMX and Hyperscript (all
coding done on the server side) and a forward chaining form rules engine
that simplifies form state management all integrated in SWI Prolog.

## React vs htmx
Here is what AI says:

React and htmx represent two divergent architectural philosophies for building web applications: React is a client-side component-based framework ideal for complex, highly interactive Single Page Applications (SPAs), while htmx is a lightweight, server-driven library that extends HTML to handle interactivity with minimal JavaScript.

__Performance and Bundle Size__

htmx offers superior initial load performance with a tiny ~14 KB bundle and no hydration delay, resulting in near-instant interactivity and high Lighthouse scores (often 94+).  In contrast, React requires a larger runtime (~44 KB base) plus application code, leading to larger bundles (150–400+ KB) and delayed Time-to-Interactive due to the client-side hydration process.

__State Management and Architecture__

htmx keeps state on the server, sending back HTML fragments to update the DOM directly, which simplifies client-side logic but increases server load.  React manages state client-side using hooks or stores, allowing for rich, responsive UI updates and offline support without round-tripping to the server, but requiring complex state synchronization logic.

__Use Cases and Ecosystem__

Choose htmx for CRUD-heavy applications, admin panels, and content sites where rapid development and simplicity are prioritized; it has a smaller ecosystem but integrates with any backend language.  Choose React for complex UIs like real-time collaboration tools, drag-and-drop interfaces, or apps requiring a shared codebase with React Native for mobile; it boasts a massive ecosystem and extensive tooling for large-scale maintenance.

| Feature	| htmx | React |
| ------- | ---- | ----- |
| Bundle Size	| ~14 KB (gzipped) |	~44 KB+ (base) + app code |
| State Location	|Server-side |	Client-side|
| Learning Curve	| Very Low (HTML-centric)	| Moderate to Steep (JSX/JS) |
| Build Step	| Not Required	| Required (Vite, Webpack, etc.) |
| Best For |	Admin panels, CRUD, internal tools	| SPAs, complex interactivity, mobile apps |
| Ecosystem |	Small, growing	| Massive, industry standard |
