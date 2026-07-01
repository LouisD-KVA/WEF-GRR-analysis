# WEF Global Risks Reports analysis

This repository contains the data-processing and analysis code for the manuscript:

**Anticipatory skill and structural biases of a major global risk assessment**  
Louis Delannoy, Mélis Busson, Peter Søgaard Jørgensen

The analysis evaluates the World Economic Forum’s *Global Risks Reports* (GRRs) using three complementary lenses:

1. a predictive analysis comparing GRPS-derived risk scores with observed national shocks;
2. a thematic analysis comparing report text and survey-derived material;
3. a linguistic analysis comparing GRRs with reports from other international organisations.

The central predictive analysis tests whether GRR risk scores align more strongly with future shocks than with recent shocks. The thematic and linguistic analyses assess how risks are represented, translated, and framed in the reports.

---

## Predictive analysis

The main script is:

```text
code/GRR_predictive_analysis_MASTER.R
```

It performs the following steps:

1. loads packages and helper functions;
2. imports GRPS-derived risk-score data;
3. imports and harmonises observed shock data;
4. maps GRR risk categories to empirical shock categories;
5. standardises shock counts by category and region;
6. estimates retrospective and prospective lag regressions;
7. computes predictive capacity and anticipatory skill;
8. generates Monte Carlo-randomised null simulations or loads precomputed simulation objects;
9. produces main-text and supporting-information figures;
10. exports diagnostic CSV files and summary tables.

## Design

The predictive analysis uses the comparable **2006–2021 GRPS-derived risk-score series**. Later GRRs are used in the thematic and linguistic analyses but are excluded from the predictive analysis because the GRPS scoring methodology changed substantially after 2021.

The analysis covers eight empirical shock categories:

- geophysical shocks;
- climate shocks;
- disease outbreaks;
- food-related ecological shocks;
- economic shocks;
- geopolitical conflicts;
- terrorism;
- technological shocks.

Observed shocks are aggregated globally and by World Bank income group:

- HIC: high-income countries;
- UMC: upper-middle-income countries;
- LMC: lower-middle-income countries;
- LIC: low-income countries.

Shock counts are standardised using a category-first procedure so that high-frequency shock categories do not mechanically dominate the regression results.

## Key metrics

For each shock category and region, the script estimates regressions between GRPS-derived risk scores and observed shock occurrence across retrospective and prospective windows of one to five years.

### Predictive capacity

**Predictive capacity** is defined as the maximum prospective regression coefficient across horizons of one to five years.

### Anticipatory skill

**Anticipatory skill** is defined as predictive capacity minus the coefficient from the corresponding retrospective horizon.

This metric distinguishes cases in which risk scores align with future shocks from cases in which they mainly reflect recent or contemporaneous events.

### Horizon

The selected horizon, denoted **h** in some figures, is the time horizon in years at which predictive capacity is maximised.

## Window convention

The current predictive specification uses windows that are inclusive of the GRR assessment year.

For a GRR year `y` and horizon `h`:

- prospective windows cover `y` to `y + h`;
- retrospective windows cover `y - h` to `y`.

The resulting coefficients should therefore be interpreted as measures of near-term prospective and retrospective alignment, not as strictly out-of-sample forecasts beginning only after the survey year.

For edition-level and annual-component diagnostic figures, partial windows are allowed when a full requested horizon extends beyond category-specific shock-data coverage. Unavailable years are not treated as zero-shock years.

## Shock-data coverage

The core shock database provides harmonised coverage up to 2019. In the working files used here, harmonised extensions are available for some categories, while other categories end earlier because of source-data limitations.

The predictive script uses the following category-specific end years:

| Shock category | End year |
|---|---:|
| Food-related ecological shocks | 2013 |
| Disease outbreaks | 2022 |
| Climate shocks | 2024 |
| Geophysical shocks | 2024 |
| Technological shocks | 2024 |
| Terrorism | 2020 |
| Geopolitical conflicts | 2023 |
| Economic shocks | 2019 |

Years outside category-specific coverage are not treated as observed zero-shock years.

## Monte Carlo simulations

The script evaluates lag-regression coefficients against Monte Carlo-randomised shock simulations.

The simulation procedure expands the shock data to a complete country × shock-category × year grid within valid category coverage, fills observed absences with zeros, and permutes annual shock counts within country–category series. The permuted counts are then reaggregated to regional and global totals, restandardised, and analysed with the same lag-regression procedure.

This preserves country–category marginal distributions while breaking temporal alignment between observed shocks and GRPS-derived risk scores.

The main lag figures use the **2.5–97.5% Monte Carlo envelope** for simulation-based classification.

## Income-group tests

Income-group differences are evaluated with Friedman omnibus tests. Shock category is treated as the paired block and income group as the repeated factor.

The main test is restricted to the four shock categories with positive global predictive capacity:

- climate shocks;
- disease outbreaks;
- geopolitical conflicts;
- terrorism.

## Reproducibility notes

Some parts of the predictive analysis can use precomputed RData simulation files to avoid rerunning computationally expensive simulations. If these objects are present, the script may load them directly. To fully regenerate the analysis, remove or ignore the precomputed objects and ensure that the helper functions and raw input files are available.

When changing core settings such as the lag-window convention, the observed regressions and Monte Carlo simulations should be regenerated under the same settings. Do not mix observed coefficients generated under one convention with simulation envelopes generated under another.

## Software requirements

The predictive analysis was written in R. Required packages include, at minimum:

```r
tidyverse
ggplot2
dplyr
tidyr
purrr
readr
stringr
broom
scales
patchwork
zoo
furrr
future
```

Additional packages may be required by helper scripts or by the thematic and linguistic analyses.

---

## Data availability

The repository is designed to include processed analysis files and code. Some raw GRR files, external shock datasets, or report PDFs may be subject to third-party access conditions and should be cited or linked rather than redistributed when required.

---

## Citation

If using this repository, please cite the associated manuscript:

Delannoy, L., Busson, M., & Søgaard Jørgensen, P. **Anticipatory skill and structural biases of a major global risk assessment**.

---

## Contact

For questions about the analysis, contact:

- Louis Delannoy: louis.delannoy@su.se
- Peter Søgaard Jørgensen: peter.sogaard.jorgensen@su.se