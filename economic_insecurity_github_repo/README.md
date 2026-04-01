# economic_insecurity

GitHub-ready distribution scaffold for the Stata package `economic_insecurity`, including the two `egen` functions `ei_abs` and `ei_rel`.

## What this repository is for

This repository is structured so the package can be published on GitHub and installed in Stata with `net install` once it is pushed to a public repository.

## Repository layout

- `economic_insecurity.pkg` — Stata package-description file used by `net install`
- `stata.toc` — package listing for `net from`
- `src/` — put the real `.ado` and `.sthlp` source files here while drafting
- `docs/index.md` — simple GitHub Pages landing page

## Files you need in the repository root before publishing

For direct installation from GitHub, these files should be in the repository root:

- `economic_insecurity.ado`
- `economic_insecurity.sthlp`
- `ei_abs.ado`
- `ei_abs.sthlp`
- `ei_rel.ado`
- `ei_rel.sthlp`
- `economic_insecurity.pkg`
- `stata.toc`