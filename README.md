# labtools

A toolbox for analysing the data produced in the lab.

> 🚧 **Work in progress**: tools are added as they are developed. Sections marked *TODO* will be filled in along the way.

---

## Table of contents

- [Purpose](#purpose)
- [Installation](#installation)
- [Repository layout](#repository-layout)
- [Tools](#tools)
- [Typical workflow](#typical-workflow)
- [Expected data formats](#expected-data-formats)
- [Adding a new tool](#adding-a-new-tool)
- [Contributing](#contributing)
- [License](#license)

---

## Purpose

`labtools` gathers R functions and scripts to:

- **import** raw data from the lab instruments;
- **clean and check** the data (missing values, outliers, duplicates);
- **analyse** the results (descriptive statistics, tests, models);
- **visualise** and **export** the results in a reusable form (figures, tables, reports).

The goal is to keep analyses **reproducible**, **documented** and **shared** across the team, rather than scattered across individual scripts.

---

## Installation

### Requirements

- [R](https://cran.r-project.org/) (version ≥ 4.1; on macOS: `brew install r`)
- [RStudio](https://posit.co/download/rstudio-desktop/) (recommended)
- Required R packages: `ggplot2` (≥ 3.5)

### Getting the project

```bash
git clone <repository-url>
cd labtools
```

Then, in R:

```r
# Install dependencies
install.packages("ggplot2")

# Load a tool
source("R/radar_plot.R")
```

---

## Repository layout

Planned structure (to be adjusted as the project grows):

```
labtools/
├── R/              # R functions (one file per tool or topic)
├── scripts/        # Ready-to-run analysis scripts
├── data/
│   ├── raw/        # Raw data (untouched; not versioned if large)
│   └── processed/  # Cleaned data
├── output/         # Generated figures, tables and reports
├── templates/      # Input templates to fill in (one per tool)
├── tests/          # Function tests
├── README.md
└── LICENSE
```

---

## Tools

| Tool | Role | Input | Output | Status |
|------|------|-------|--------|--------|
| [`radar_from_file()`](#radar_from_file--radar-charts-of-mediators-vs-a-reference) | Radar charts of cytokines / oxylipins per condition, as fold change vs a reference, with significance stars | CSV ([template](templates/radar_template.csv)) | One PNG + PDF per group, CSV of normalised values | ✅ |

### Detailed description

#### `radar_from_file()` — radar charts of mediators vs a reference

- **Purpose**: R version of the Excel template *Modele_radar_ATB_cytokines_oxylipines*. Draws one radar per group of conditions; each branch is a mediator (cytokine, oxylipin…) and each curve a condition, expressed as log2 fold change (or fold change) vs the reference condition. The reference is the grey dashed polygon (0 in log2 FC, 1 in FC). Branch labels are green for anti-inflammatory / pro-resolving mediators and red for pro-inflammatory ones.
- **Files**: [`R/radar_plot.R`](R/radar_plot.R) (functions), [`scripts/radar_cytokines.R`](scripts/radar_cytokines.R) (ready to run), [`templates/radar_template.csv`](templates/radar_template.csv) (input template, illustrative values).
- **Input**: a CSV file (comma, or semicolon with decimal comma as exported by a French Excel), one row per condition:

  | Condition | Groupe | IL-10 | … | 5-HETE | IL-10_sig | … | 5-HETE_sig |
  |-----------|--------|-------|---|--------|-----------|---|------------|
  | Catégorie | | anti | … | pro | | | |
  | Non traité | Référence | 90.7 | … | 2629816 | | | |
  | Colistin | ATB paroi/membrane | 12055.9 | … | 566985 | ** | … | * |

  - `Groupe` = `Référence` on exactly one row: the reference condition (needed for the fold change, not drawn as a condition).
  - `Groupe` = any other text: one radar per group, conditions drawn in table order (up to 8 per radar). `Ne pas afficher` or empty = row ignored.
  - Value columns = mean concentrations (cytokines) or mean peak areas (oxylipins). Branch order on the radar = column order, starting at the top and going counter-clockwise (as in the Excel file). Any number of branches (≥ 3).
  - `<branch>_sig` columns (optional): `*`, `**`, `***` or `****` vs the reference, empty if ns.
  - `Catégorie` row (optional): `anti` or `pro` per branch, to colour the labels.
- **Output** (in `output/radar/` by default): `radar_01_<group>.png/.pdf`, … and `valeurs_normalisees_log2fc.csv` (equivalent of the *2_Normalisé* sheet).
- **Where the stars go**: radar with a single condition → next to the branch name; with several conditions → in the legend, e.g. `Ciprofloxacin (IL-10 ***, RvD1 *, …)`.
- **Main parameters**:
  - `normalisation`: `"log2fc"` (default) or `"fc"`.
  - `show_stars`: `TRUE` (default) / `FALSE`.
  - `limits`: scale, e.g. `c(-3, 10)` as in the Excel file; `NULL` (default) = automatic, shared by all radars.
  - `step`: spacing of the grid rings (default 2 in log2 FC).
  - `formats`, `width`, `height`, `dpi`, `title`, `clockwise`.
- **Example**:

  ```bash
  Rscript scripts/radar_cytokines.R data/raw/my_data.csv output/radar
  ```

  ```r
  source("R/radar_plot.R")
  plots <- radar_from_file("data/raw/my_data.csv", limits = c(-3, 10))
  plots[["ATB autre"]]  # ggplot object, can be further customised
  ```

- **Known limitations**: means only (the fold change is computed on the means, as in the Excel file); stars are not computed, they come from your own post-hoc test (e.g. Dunnett vs untreated in Prism, or FDR for oxylipins). The *5_Source_oxylipines* traceability sheet of the Excel file has no chart and is not reproduced. Remember to state the test and thresholds in the figure legend (* p < 0.05; ** p < 0.01; *** p < 0.001; **** p < 0.0001).

#### Template for documenting a new tool

#### `tool_name()` — *short description*

- **Purpose**: what the tool does, in one or two sentences.
- **Input**: expected file or object type (e.g. CSV exported from instrument X).
- **Output**: what is produced (data frame, figure, file…).
- **Main parameters**:
  - `param1`: description
  - `param2`: description
- **Example**:

  ```r
  result <- tool_name("data/raw/my_file.csv", param1 = ...)
  ```

- **Known limitations**: unsupported cases, assumptions made.

---

## Typical workflow

Example of a full analysis pipeline (to be completed once the tools exist):

```r
# 1. Import
data <- import_data(...)

# 2. Clean
clean_data <- clean(data)

# 3. Analyse
results <- analyse(clean_data)

# 4. Visualise / export
plot_results(results)
export_results(results, "output/")
```

---

## Expected data formats

Describe here the formats produced in the lab and supported by the tools:

| Source / instrument | Format | Main columns | Notes |
|---------------------|--------|--------------|-------|
| Mean concentrations / peak areas per condition (ELISA, LC-MS oxylipins) | CSV | `Condition`, `Groupe`, one column per mediator, optional `<mediator>_sig` | Input of `radar_from_file()`; see [templates/radar_template.csv](templates/radar_template.csv) |

> ⚠️ Do not commit sensitive or confidential data to this repository.

---

## Adding a new tool

1. Create a dedicated branch: `git checkout -b tool/<name>`
2. Write the function in `R/` and document it (comments or [roxygen2](https://roxygen2.r-lib.org/)).
3. Add a usage example and, if possible, a test in `tests/`.
4. Update the [Tools](#tools) table and the detailed description in this README.
5. Open a pull request to `main`.

---

## Contributing

Suggestions, bug reports and improvements are welcome through *issues* and *pull requests*.

---

## License

This project is released under the MIT License. See the [LICENSE](LICENSE) file.
