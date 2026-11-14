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

- [R](https://cran.r-project.org/) (version ≥ *TODO*)
- [RStudio](https://posit.co/download/rstudio-desktop/) (recommended)
- Required R packages: *TODO* (e.g. `tidyverse`, `readxl`…)

### Getting the project

```bash
git clone <repository-url>
cd labtools
```

Then, in R:

```r
# Install dependencies (adjust as needed)
install.packages(c("tidyverse", "readxl"))

# Load the tools
source("R/<file_name>.R")
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
├── tests/          # Function tests
├── README.md
└── LICENSE
```

---

## Tools

| Tool | Role | Input | Output | Status |
|------|------|-------|--------|--------|
| *TODO* | | | | 🚧 |

### Detailed description

Each tool is documented using the template below.

#### `tool_name()` — *TODO*

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
| *TODO* | | | |

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
