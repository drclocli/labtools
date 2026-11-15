# labtools

A toolbox for analysing the data produced in the lab, packaged as an R
package. Each tool is:

- an **R function** in `R/` that takes the input data and an output folder,
  writes its files and returns their absolute paths;
- a **command line app** in `exec/`, built with [Rapp](https://github.com/r-lib/Rapp),
  installed as a launcher in `~/.local/bin`.

---

## Table of contents

- [Installation](#installation)
- [Commands](#commands)
  - [`radar-plot`](#radar-plot--radar-charts-of-mediators-vs-a-reference)
- [Common behaviour of all commands](#common-behaviour-of-all-commands)
- [Using the tools from R](#using-the-tools-from-r)
- [Repository layout](#repository-layout)
- [Adding a new tool](#adding-a-new-tool)
- [Development: tests and checks](#development-tests-and-checks)
- [License](#license)

---

## Installation

### Requirements

- [R](https://cran.r-project.org/) ≥ 4.1 (macOS: `brew install r`).
- With Homebrew R, packages are built from source. You need:
  - the Rust compiler, for `yaml12`, a dependency of Rapp: `brew install rust`;
  - for devtools only (development): `brew install openssl@3 harfbuzz fribidi libtiff webp`.

### Install or update

From anywhere:

```bash
/path/to/labtools/install.sh
```

or, from the repository:

```bash
./install.sh
```

The script can be run as many times as needed. It:

1. installs `pak` and `Rapp` if they are missing;
2. installs the package and its dependencies (`pak::local_install()`);
3. installs or updates the launchers (`Rapp::install_pkg_cli_apps("labtools")`).
   Only files previously written by Rapp are replaced;
4. prints the installed commands and their location.

Run `./install.sh` again after pulling changes or **after upgrading R**. The
launchers call the `Rscript` of the R that installed them by its absolute
path, for example `/opt/homebrew/Cellar/r/4.6.2/...`, and that path changes
when Homebrew upgrades R.

### Where the commands are installed

Launchers go to `~/.local/bin` (macOS and Linux). Set `RAPP_BIN_DIR` to
choose another folder: `RAPP_BIN_DIR=/some/bin ./install.sh`.

On this machine:

```
$ which radar-plot
/Users/chloetorres/.local/bin/radar-plot
```

| Command      | Launcher (absolute path, for Raycast or other tools) |
|--------------|-------------------------------------------------------|
| `radar-plot` | `/Users/chloetorres/.local/bin/radar-plot`            |

A launcher is a small `sh` script, for example:

```sh
exec /opt/homebrew/Cellar/r/4.6.2/lib/R/bin/Rscript '--default-packages=base,methods,utils,grDevices,graphics,stats,labtools' -e 'Rapp::run()' '/opt/homebrew/lib/R/4.6/site-library/labtools/exec/radar-plot.R' "$@"
```

If `~/.local/bin` is not on your `PATH`, Rapp adds it to `~/.zprofile` on
macOS. Open a new terminal, or use the absolute path above. To remove the
launchers, run `Rscript -e 'Rapp::uninstall_pkg_cli_apps("labtools")'`.

---

## Commands

### `radar-plot`: radar charts of mediators vs a reference

R version of the Excel template *Modele_radar_ATB_cytokines_oxylipines*.
Draws one radar per group of conditions. Each branch is a mediator
(cytokine, oxylipin…) and each curve a condition, as log2 fold change (or
fold change) vs the reference condition. The reference is the grey dashed
polygon (0 in log2 FC, 1 in FC). Branch labels are green for
anti-inflammatory / pro-resolving mediators and red for pro-inflammatory ones.

```bash
radar-plot data.csv                                  # files in the current folder
radar-plot data.csv --out figures                    # ./figures, created if needed
radar-plot data.csv -o /abs/path -f png -f svg       # absolute folder, PNG + SVG
radar-plot data.csv --limits=-3,10 --normalisation fc
radar-plot data.csv --json                           # machine-readable output
radar-plot --help
```

**Input**: one CSV file, required. The separator is a comma, or a semicolon
with decimal comma (French Excel). The file must be UTF-8. There is one row
per condition. Template: [`inst/extdata/radar_example.csv`](inst/extdata/radar_example.csv),
with illustrative values.

| Condition | Groupe | IL-10 | … | 5-HETE | IL-10_sig | … | 5-HETE_sig |
|-----------|--------|-------|---|--------|-----------|---|------------|
| Catégorie | | anti | … | pro | | | |
| Non traité | Référence | 90.7 | … | 2629816 | | | |
| Colistin | ATB paroi/membrane | 12055.9 | … | 566985 | ** | … | * |

- `Condition` and `Groupe` (or `Group`) are required.
- Exactly one row has `Groupe` = `Référence`. This is the reference
  condition, and all its values must be positive.
- Any other `Groupe` value gives one radar per group, with conditions drawn in
  table order (at most 8 per radar). Rows with `Ne pas afficher` or an empty
  group are ignored.
- Value columns hold mean concentrations or mean peak areas. You need at
  least 3 of them. Column order is the branch order, counter-clockwise from
  the top.
- `<mediator>_sig` columns are optional: `*` to `****`, empty if not
  significant.
- The `Catégorie` row is optional: `anti` or `pro` per mediator, to colour
  the labels.

**Outputs**, written to the output folder:

- `radar_NN_<group>.<format>`: one file per group and per format. `<group>`
  is the group name in ASCII, with `_` in place of special characters.
  Default formats: **PNG and PDF**. PDFs are written with cairo, so α and β
  display correctly.
- `valeurs_normalisees_<log2fc|fc>.csv`: the normalised values, equivalent
  to the *2_Normalisé* sheet.

**Options**

| Option | Default | Description |
|--------|---------|-------------|
| `<INPUT>` | *(required)* | input CSV file |
| `-o, --out <DIR>` | current folder | output folder, created if needed |
| `-f, --format <FMT>` | `png` and `pdf` | `png`, `pdf`, `svg` (needs the svglite package) or `tiff`. Repeat the option for several formats |
| `--normalisation` | `log2fc` | `log2fc` or `fc` |
| `--limits=<min,max>` | automatic | e.g. `--limits=-3,10`. Use `=` when the value starts with `-` |
| `--step` | `0` (automatic) | spacing between rings (2 in log2 FC) |
| `--no-stars` | stars shown | hide significance stars |
| `--no-title` | title shown | no group name as title |
| `--clockwise` | counter-clockwise | branch direction |
| `--width`, `--height` | `9`, `6` | figure size in inches |
| `--dpi` | `300` | resolution of PNG/TIFF (integer) |
| `--json` | off | print only the JSON result on stdout |

**Stars**: with a single condition on a radar, they appear next to the branch
name. With several conditions, they appear in the legend, e.g.
`Ciprofloxacin (IL-10 ***, RvD1 *, …)`.

**Known limitations**: the fold change is computed on the means, as in the
Excel file. Stars are not computed: they come from your own post-hoc test
(e.g. Dunnett vs untreated, or FDR for oxylipins). State the test and the
thresholds in the figure legend.

---

## Common behaviour of all commands

- **Required inputs are positional arguments**, and options start with `--`.
  `<command> --help` lists them.
- **Relative paths** (inputs and `--out`) are resolved against the folder
  the command is launched from.
- **`--out`**: output folder, created if needed. **If omitted, files are
  written to the current folder**, not to the repository or the package
  folder.
- **`--json`**: stdout contains only one line, for programs such as Raycast:

  ```json
  {"files":["/abs/path/radar_01_ATB_paroi_membrane.png","/abs/path/radar_01_ATB_paroi_membrane.pdf","/abs/path/valeurs_normalisees_log2fc.csv"]}
  ```

  Paths are absolute. `files` is always an array.
- **Messages** (progress, warnings, list of created files) go to **stderr**.
- **Errors** are also on stderr, and the exit status is non-zero. This
  covers a missing file, missing columns, an unsupported input or output
  format, an invalid option value, and a missing argument.

---

## Using the tools from R

```r
library(labtools)
example <- system.file("extdata", "radar_example.csv", package = "labtools")

files <- radar_plots(example, out_dir = "figures", limits = c(-3, 10),
                     formats = c("png", "pdf"))
files                                  # absolute paths of the files created

plots <- radar_build(example)          # ggplot objects, nothing written
plots[["ATB autre"]]
```

---

## Repository layout

```
labtools/
├── DESCRIPTION, NAMESPACE           # package metadata (NAMESPACE generated by roxygen2)
├── R/
│   ├── radar.R                      # radar tool: radar_plots(), radar_build()
│   ├── cli-helpers.R                # shared helpers: inputs, output folder, JSON, errors
│   └── labtools-package.R
├── exec/
│   └── radar-plot.R                 # Rapp app = `radar-plot` command
├── inst/extdata/radar_example.csv   # example input / template
├── tests/testthat/                  # unit tests
├── man/                             # generated documentation
├── install.sh
└── README.md
```

Lab data and generated figures are never versioned (see `.gitignore`).

---

## Adding a new tool

Convention: **one tool = one function in `R/` + one script in `exec/`.**

1. **Function** `R/<tool>.R`:
   - signature `my_tool(path, out_dir = ".", ...)`;
   - validate the inputs with the internal helpers `check_input_file(path, ext = "csv")`,
     `check_formats(formats, allowed)` and `cli::cli_abort()` for data errors;
   - get the output folder with `out_dir <- resolve_out_dir(out_dir)`, which
     handles the default (current folder) and creates the folder;
   - write the files and **return their absolute paths** (`normalizePath(files)`);
   - no hard-coded paths and no `source()`. Human messages go through `cli::cli_inform()`;
   - document it with roxygen2 and `@export`.
2. **App** `exec/<tool-name>.R`, copied from `exec/radar-plot.R`:

   ```r
   #!/usr/bin/env Rapp
   #| name: my-tool
   #| description: What the tool does.
   #| launcher:
   #|   default-packages: [base, methods, utils, grDevices, graphics, stats, labtools]

   #| description: Input CSV file.
   input <- NULL              # NULL = required positional argument

   #| description: Output folder. Default is the current folder.
   #| short: o
   out <- ""                  # "" = string option, default handled by resolve_out_dir()

   #| description: Print only {"files":[...]} on stdout.
   json <- FALSE              # FALSE = flag --json

   labtools::cli_main({
     files <- labtools::my_tool(input, out_dir = out)
     labtools::cli_emit_files(files, json = json)
   })
   ```

   How Rapp turns top-level assignments into arguments (Rapp ≥ 0.4):

   | In the script | On the command line |
   |---|---|
   | `x <- NULL` | **required** positional argument `<X>` (`#| required: false` makes it optional) |
   | `x <- ""` / `x <- 1L` / `x <- 1.5` | option `--x` of type string / integer / float with this default (types are checked, not coerced) |
   | `x <- FALSE` / `x <- TRUE` | flag `--x` / `--no-x` |
   | `x <- c()` | repeatable option (`--x a --x b`) |
   | `#| description:`, `#| short:` above it | help text and short alias (`-o`) |

   `--help` is generated by Rapp. Options cannot default to `NULL`, so use
   `""` or `0` to mean "automatic". Keep the `launcher: default-packages`
   line: ggplot2 legends need `graphics` to be attached.
3. **Tests** in `tests/testthat/test-<tool>.R`, with a small input file in
   `inst/extdata/` or `tests/testthat/fixtures/`.
4. Add a section to [Commands](#commands), then run `./install.sh`. New apps
   in `exec/` are picked up automatically.

---

## Development: tests and checks

In R, from the repository:

```r
devtools::document()   # regenerate NAMESPACE and man/
devtools::test()       # unit tests
devtools::check()      # R CMD check (expected: 0 errors, 0 warnings, 0 notes)
```

To try an app without installing the launcher:

```r
Rapp::run("exec/radar-plot.R", c("inst/extdata/radar_example.csv", "--out", tempdir()))
```

---

## License

MIT. See [LICENSE.md](LICENSE.md).
