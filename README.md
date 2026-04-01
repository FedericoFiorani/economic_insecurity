# economic_insecurity package

GitHub-ready distribution scaffold for the Stata package `economic_insecurity`, including the two `egen` functions `ei_abs` and `ei_rel`, and the summary command `economic_insecurity`.

## Aim of this repository

This repository is structured so that the package can be installed in Stata with `net install` while it is under revision at the *Stata Journal*.

## Repository content

- `economic_insecurity.ado` — summary command
- `economic_insecurity.sthlp` — help file for the summary command
- `ei_abs.ado` — `egen` function for the absolute economic insecurity index
- `ei_abs.sthlp` — help file for `ei_abs`
- `ei_rel.ado` — `egen` function for the relative economic insecurity index
- `ei_rel.sthlp` — help file for `ei_rel`
- `economic_insecurity.pkg` — Stata package-description file used by `net install`
- `stata.toc` — package listing used by `net from`
- `index.md` — simple GitHub Pages landing page

## Installation in Stata

The package can be installed directly from GitHub with:

```stata
net install economic_insecurity, from("https://raw.githubusercontent.com/FedericoFiorani/economic_insecurity/main/") replace ```

To inspect the package before installation, use:

```net describe economic_insecurity, from("https://raw.githubusercontent.com/FedericoFiorani/economic_insecurity/main/")```