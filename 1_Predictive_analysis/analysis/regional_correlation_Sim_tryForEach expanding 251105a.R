# ====================================================================
# Regional risk–shock correlation with randomization simulation
# Based on Delannoy et al. Global Sustainability polycrisis database
# ====================================================================

# -------------------------------
# Libraries
# -------------------------------
library(dplyr)
library(tidyr)
library(purrr)
library(broom)
library(ggplot2)
library(forcats)
library(countrycode)
library(wbstats)
library(furrr) ## parrellel processing



# ====================================================================
# ----------------------------- MAIN ---------------------------------
# ====================================================================

# ---- Paths ----
wd <- "C:\\Users\\psoga\\Cloud-Drive\\ESCAPE\\WEF"
setwd(wd)


############ LOAD PREVIOUS SIMULATION DATAFRAMES FOR ANALYSIS

load("res_glob_sim_ann_1000_2025-10-16.RData")
load("res_glob_sim_500_2025-10-16.RData")
load("res_sim_5000_2025-10-15.RData")


# ====================================================================
# --------------------------- SOURCE FUNCTIONS ------------------------------
# ====================================================================
source("sim_functions.r")

source("run_lag_worker.r")


# ---- Data ----
risks      <- read.csv("Risks 251014.csv") # old file: "Risks.csv"
sh_nat     <- read.csv("Shock counts.csv")
reg_key    <- read.csv("r5regions.csv", col.names = c("Region","ISO3"))

# ---- Country codes ----
sh_nat <- sh_nat %>%
  mutate(ISO3 = countrycode(Country.name, "country.name", "iso3c"))

# ---- Income groups ----
meta <- wbstats::wb_cachelist$countries
inc_key <- meta %>% select(iso3c, income_level_iso3c)
sh_nat <- sh_nat %>%
  left_join(inc_key, by = c("ISO3" = "iso3c")) %>%
  rename(IncomeGroup = income_level_iso3c)

# ---- Cleaning ----
sh_nat <- sh_nat %>% filter(Shock.type != "Infestation",
                            Year > (min(risks$Year) - 6)) %>%
  mutate(
    Shock.category = if_else(
      Shock.type == "Infectious disease" & Shock.category == "ECOLOGICAL", "DISEASES", Shock.category),
    Shock.category = if_else(
      Shock.type == "Terrorist attack" & Shock.category == "CONFLICTS", "TERRORISM", Shock.category)
  )

# ---- Category cutoff ----
end_years <- tibble::tribble(
  ~Shock.category, ~LastYear,
  "ECOLOGICAL", 2013, "DISEASES", 2022, "CLIMATIC", 2024,
  "TECHNOLOGICAL", 2024, "GEOPHYSICAL", 2024,
  "TERRORISM", 2020, "CONFLICTS", 2023, "ECONOMIC", 2019
)
sh_nat <- sh_nat %>%
  left_join(end_years, by = "Shock.category") %>%
  filter(Year <= LastYear) %>% select(-LastYear)

# ---- Regional aggregation (real) ----
sh_reg <- make_shocks_reg(sh_nat, reg_key, "category_first", "income", cutoff = TRUE)

# ---- Risk data ----
risks_long <- risks %>% pivot_longer(-Year, names_to = "Risk_Type", values_to = "Risk_Score")

# ---- Mapping ----
map_risk <- c(
  "CLIMATIC"="Climate","GEOPHYSICAL"="Geophysical","ECOLOGICAL"="Food",
  "TECHNOLOGICAL"="Tech","CONFLICTS"="GeoConflict","ECONOMIC"="Economic",
  "DISEASES"="Diseases","TERRORISM"="Terror"
)
sh_reg <- sh_reg %>% mutate(Shock_Type = recode(Shock_Type, !!!map_risk))

# ---- Lag windows ----
lag_win <- tibble(
  Lag_Label = c(-1, 0, 1),
  Start_Offset = c(-5, -2, 1),
  End_Offset   = c(-1,  2, 5)
)

#### OLD CODE FOR SIMULATIONS AND PLOTTING
sim_reg_annual_smooth_sum <- res_sim_reg_annual_smooth %>%
  group_by(Region, Risk_Type, Lag) %>%
  summarise(
    mean_sim = mean(estimate, na.rm = TRUE),
    sd_sim   = sd(estimate, na.rm = TRUE),
    q05      = quantile(estimate, 0.05, na.rm = TRUE),
    q95      = quantile(estimate, 0.95, na.rm = TRUE),
    .groups = "drop"
  )

comp_reg_annual <- res_reg_annual_smooth %>%
  rename(real_est = estimate) %>%
  left_join(sim_reg_annual_smooth_sum,
            by = c("Region", "Risk_Type", "Lag")) %>%
  mutate(
    z = (real_est - mean_sim) / sd_sim,
    signif = real_est < q05 | real_est > q95
  )

comp_reg_annual <- comp_reg_annual %>% mutate(sig.two = ifelse(signif == TRUE & p.value < 0.05,"BOTH",ifelse(
  signif == TRUE & p.value > 0.05,"SIM",ifelse(signif != TRUE & p.value < 0.05,
                                               "REG","NONE") 
)))
comp_reg_annual$sig.two <- factor(comp_reg_annual$sig.two,levels=c("BOTH","SIM","REG","NONE"))


comp_reg_annual$Region<-factor(comp_reg_annual$Region,levels=c("HIC","UMC","LMC","LIC"))

comp_reg_annual$Risk_Type<-factor(comp_reg_annual$Risk_Type,levels=c(
    "Geophysical","Climate","Diseases","Food","Economic","GeoConflict","Terror","Tech"))


x11()
ggplot(comp_reg_annual, aes(x = Lag, y = real_est)) +
  geom_ribbon(aes(fill = Region, ymin = q05, ymax = q95),
              alpha = 0.3) +
  geom_point(aes(colour = sig.two), size = 2) +
  geom_line(aes(group = Region), alpha = 0.4) +
  facet_grid(Region ~ Risk_Type) +
  labs(y = "Coefficient (annual shocks vs. simulated 5–95%)",
       x = "Lag (years)", colour = "Significant (5%)") +
  geom_hline(yintercept = 0) + geom_vline(xintercept = 0)+
  scale_color_discrete(type=rev(c("#f7f7f7","#969696","#737373","#000000")))+
  theme_bw()


############# expanding time window

  ### regression

# --------------------------------------------------------------------
# Precompute smoothed & aggregated shocks for each lag window (1–5)
# --------------------------------------------------------------------

max_lag <- 5
smoothed_reg_sets <- purrr::map(1:max_lag, function(w) {
  message("Preparing smoothed data for window = ", w)
  sh_tmp <- if (w == 1) sh_nat else smooth_nat_shocks(sh_nat, window = w)
  make_shocks_reg(
    sh_tmp, reg_key,
    method = "category_first",
    reg_level = "income",
    cutoff = TRUE
  ) %>%
    mutate(Shock_Type = recode(Shock_Type, !!!map_risk))
})
names(smoothed_reg_sets) <- paste0("lag", 1:max_lag)

  
res_reg_expand_fast <- purrr::pmap_dfr(
  expand_grid(
    Region = unique(smoothed_reg_sets$lag1$Region),
    Risk_Type = intersect(unique(risks_long$Risk_Type),
                          unique(smoothed_reg_sets$lag1$Shock_Type))
  ),
  function(Region, Risk_Type) {
    run_reg_expand_reg(
      region = Region,
      rtype = Risk_Type,
      max_lag = max_lag,
      risks_long = risks_long,
      smoothed_reg_sets = smoothed_reg_sets,
      include0 = TRUE
    )
  }
) %>%
  filter(term == "Risk_Score")


save(res_reg_expand_fast,file=paste("expanding_res_",Sys.Date(),".RData",sep=""))





# --------------------------------------------------------------------
# Simulation setup (Windows-friendly parallel)
# --------------------------------------------------------------------
n_sim_expand <- 500       # number of Monte Carlo iterations
max_lag      <- 5         # expanding window horizon
reg_level    <- "income"  # or "custom"
include0     <- TRUE      # include the risk year
min_n        <- 5
n_workers    <- 10


# Make/refresh randomisations on disk (idempotent)
dir.create("rand_cache", showWarnings = FALSE)
existing <- length(list.files("rand_cache", pattern = "^rand_\\d+\\.rds$"))
if (existing < n_sim_expand) {
  message("Generating ", n_sim_expand - existing, " randomisations...")
  purrr::walk((existing + 1):n_sim_expand, \(i) {
    sh_sim <- rand_shocks(sh_nat)
    saveRDS(sh_sim, file = file.path("rand_cache", sprintf("rand_%04d.rds", i)))
  })
}
rand_files <- list.files("rand_cache", full.names = TRUE, pattern = "^rand_\\d+\\.rds$")


# --------------------------------------------------------------------
# Top-up randomisations from 501–1000 with reproducible seeding
# --------------------------------------------------------------------

library(purrr)

# Parameters
base_seed  <- 20251106       # ← fixed base seed for reproducibility
target_n   <- 1000           # total number desired
start_from <- 501            # where to resume numbering
end_at     <- target_n

dir.create("rand_cache", showWarnings = FALSE)

# Check what already exists
existing_files <- list.files("rand_cache", pattern = "^rand_\\d{4}\\.rds$")
existing_ids <- as.integer(sub("^rand_(\\d{4})\\.rds$", "\\1", existing_files))
missing_ids <- setdiff(start_from:end_at, existing_ids)

if (length(missing_ids) == 0) {
  message("✅ Already have randomisations up to ", target_n, ". Nothing to add.")
} else {
  message("🧩 Generating ", length(missing_ids), " new randomisations (",
          sprintf("%04d", min(missing_ids)), "–", sprintf("%04d", max(missing_ids)), ")...")
  
  purrr::walk(missing_ids, \(i) {
    set.seed(base_seed + i)     # reproducible per index
    sh_sim <- rand_shocks(sh_nat)
    saveRDS(sh_sim, file = file.path("rand_cache", sprintf("rand_%04d.rds", i)))
  })
  
  message("✅ Finished creating ", length(missing_ids), " randomisation files.")
}

# Refresh list
rand_files <- list.files("rand_cache", full.names = TRUE, pattern = "^rand_\\d{4}\\.rds$")
message("📦 Total randomisations available: ", length(rand_files))


###


# Balanced lag groups (pair -k with +k)
make_lag_groups_pairs <- function(lags, n_workers, drop0 = TRUE) {
  if (drop0) lags <- setdiff(lags, 0)
  ks <- sort(unique(abs(lags)), decreasing = TRUE)
  pairs <- lapply(ks, function(k) c(-k, k)[c(-k, k) %in% lags])
  groups <- vector("list", n_workers)
  for (i in seq_along(pairs)) {
    w <- ((i - 1) %% n_workers) + 1
    groups[[w]] <- c(groups[[w]], pairs[[i]])
  }
  Filter(length, groups)
}
lags <- -max_lag:max_lag
lag_groups <- make_lag_groups_pairs(lags, n_workers, drop0 = TRUE)
print(lag_groups)

# --- Custom lag groups (manual pairing) ---
lag_groups <- list(
  c(-5),
  c(5),
  c(1),
  c(4),
  c(-1),
  c(-3),
  c(3),
  c(-4),
  c(2),
  c(-2)
)

print(lag_groups)

#install.packages("doParallel")
#install.packages("foreach")
#install.packages("doRNG")

# Cluster + foreach backend
library(doParallel)
library(foreach)
library(doRNG)

# Only use randomisation files 501–1000
rand_files_subset <- rand_files[501:1000]


time.start<-Sys.time()

# (recommended) avoid nested threading inside each worker
Sys.setenv(
  OMP_NUM_THREADS = 1,
  MKL_NUM_THREADS = 1,
  OPENBLAS_NUM_THREADS = 1,
  BLIS_NUM_THREADS = 1
)


# if you're using doParallel/foreach:
cl <- parallel::makeCluster(min(n_workers, length(lag_groups)))
doParallel::registerDoParallel(cl)
registerDoRNG(123)                           # reproducible RNG across workers
dir.create("logs", showWarnings = FALSE)

# Ensure required packages loaded on workers
parallel::clusterEvalQ(cl, {
  library(dplyr); library(tidyr); library(purrr); library(broom)
})

# Export functions/objects the workers need
parallel::clusterExport(
  cl,
  varlist = c(
    # functions you sourced
    "run_lag_worker", "run_reg_expand_reg",
    "make_shocks_reg", "smooth_nat_shocks", "rand_shocks",
    # data / objects
    "sh_nat", "rand_files_subset", "reg_key", "risks_long", "map_risk",
    # args used inside run_lag_worker call
    "reg_level", "include0", "min_n"
  ),
  envir = .GlobalEnv
)


# Run: each worker handles one lag group (balanced heavy/light)
res_lag_parallel2 <- foreach(
  g = seq_along(lag_groups),
  .combine  = dplyr::bind_rows,
  .inorder  = FALSE,
  .packages = c("dplyr","tidyr","purrr","broom")
) %dopar% {
  pid <- Sys.getpid()
  log_file <- file.path("logs", sprintf("worker_%s_group_%s.log", pid, g))
  cat(format(Sys.time(), "%H:%M:%S"), "| start group", g, "lags:",
      paste(lag_groups[[g]], collapse = ","), "\n", file = log_file, append = TRUE)
  
  t0 <- Sys.time()
  out <- run_lag_worker(
    lag_set    = lag_groups[[g]],
    sh_nat     = sh_nat,
    rand_files = rand_files_subset,
    reg_key    = reg_key,
    risks_long = risks_long,
    map_risk   = map_risk,
    reg_level  = reg_level,
    include0   = include0,
    min_n      = min_n
  )
  
  cat(format(Sys.time(), "%H:%M:%S"), "| done group", g, "rows:", nrow(out),
      "dur:", round(difftime(Sys.time(), t0, units = "mins"), 2), "min\n",
      file = log_file, append = TRUE)
  out
}

parallel::stopCluster(cl); gc()

Sys.time()-time.start

save(res_lag_parallel,file=paste("expanding_sim_500b_",Sys.Date(),".RData",sep=""))

#############


sim_expand_smooth_sum <- res_lag_parallel %>%
  group_by(Region, Risk_Type, Lag) %>%
  summarise(
    mean_sim = mean(estimate, na.rm = TRUE),
    sd_sim   = sd(estimate, na.rm = TRUE),
    q05      = quantile(estimate, 0.05, na.rm = TRUE),
    q95      = quantile(estimate, 0.95, na.rm = TRUE),
    .groups = "drop"
  )

comp_reg_expand <- res_reg_expand_fast %>%
  rename(real_est = estimate) %>%
  left_join(sim_expand_smooth_sum,
            by = c("Region", "Risk_Type", "Lag")) %>%
  mutate(
    z = (real_est - mean_sim) / sd_sim,
    signif = real_est < q05 | real_est > q95
  )

comp_reg_expand <- comp_reg_expand %>% mutate(sig.two = ifelse(signif == TRUE & p.value < 0.05,"BOTH",ifelse(
  signif == TRUE & p.value > 0.05,"SIM",ifelse(signif != TRUE & p.value < 0.05,
                                               "REG","NONE") 
)))
comp_reg_expand$sig.two <- factor(comp_reg_expand$sig.two,levels=c("BOTH","SIM","REG","NONE"))


comp_reg_expand$Region<-factor(comp_reg_expand$Region,levels=c("HIC","UMC","LMC","LIC"))

comp_reg_expand$Risk_Type<-factor(comp_reg_expand$Risk_Type,levels=c(
  "Geophysical","Climate","Diseases","Food","Economic","GeoConflict","Terror","Tech"))


x11()
ggplot(comp_reg_expand, aes(x = Lag, y = real_est)) +
  geom_ribbon(aes(fill = Region, ymin = q05, ymax = q95),
              alpha = 0.3) +
  geom_point(aes(colour = sig.two), size = 2) +
  geom_line(aes(group = Region), alpha = 0.4) +
  facet_grid(Region ~ Risk_Type) +
  labs(y = "Coefficient (observed shocks vs. simulated 5–95%)",
       x = "Max lag (years)", colour = "Significant (5%)") +
  geom_hline(yintercept = 0) + geom_vline(xintercept = 0)+
  scale_color_discrete(type=rev(c("#f7f7f7","#969696","#737373","#000000")))+
  theme_bw()





################### PLOT PAIRWISE PLOTS
library(dplyr)
library(tidyr)
library(purrr)
library(ggplot2)
library(ggrepel)

# 1) Give the global data a Region label and align columns
comp_glob_tagged <- comp_glob_expand %>%
  mutate(Region = factor("Global")) %>%      # label global
  # reorder columns to roughly match; bind_rows will fill missing (e.g., signif, sig.two) with NA
  relocate(Region, .after = p.value)

# 2) Combine
comp_all_expand <- bind_rows(comp_reg_expand, comp_glob_tagged)

# 3) Per-region summaries (avg future, diff future−past, lag of max)
comp_summary_all <- comp_all_expand %>%
  group_by(Region, term, Risk_Type) %>%
  summarise(
    avg_future = mean(real_est[Lag %in% 1:5],  na.rm = TRUE),
    avg_past   = mean(real_est[Lag %in% -5:-1], na.rm = TRUE),
    diff_future_past = avg_future - avg_past,
    lag_max = Lag[which.max(replace(real_est, is.na(real_est), -Inf))],
    .groups = "drop"
  )

# 4) Assemble pairwise panels
pairs_long <- bind_rows(
  comp_summary_all %>%
    transmute(pair = "Avg Future vs Diff(Future − Past)",
              x = avg_future, y = diff_future_past,
              term, Risk_Type, Region),
  comp_summary_all %>%
    transmute(pair = "Avg Future vs Lag of Max",
              x = avg_future, y = lag_max,
              term, Risk_Type, Region),
  comp_summary_all %>%
    transmute(pair = "Diff(Future − Past) vs Lag of Max",
              x = diff_future_past, y = lag_max,
              term, Risk_Type, Region)
)

# 5) Facet-specific symmetric limits (by pair AND region) using invisible corners
facet_limits <- pairs_long %>%
  group_by(pair, Region) %>%
  summarise(
    lim_x = max(abs(x), na.rm = TRUE),
    lim_y = max(abs(y), na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(data = map2(lim_x, lim_y, ~
                       tibble(x = c(-.x, .x, -.x, .x),
                              y = c(-.y, -.y,  .y,  .y))
  )) %>%
  unnest(data)

### plot order of region levels

pairs_long$Region<-factor(pairs_long$Region,levels=c("Global","HIC","UMC","LMC","LIC")) 

# 6) Plot: facets by Region (rows) × Pair (cols), symmetric axes per facet
x11()
ggplot(pairs_long, aes(x = x, y = y, color = Risk_Type, label = term)) +
  geom_blank(data = facet_limits, inherit.aes = FALSE, aes(x = x, y = y)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey60") +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey60") +
  geom_point(size = 3, alpha = 0.9) +
  #geom_text_repel(size = 3, show.legend = FALSE, max.overlaps = Inf) +
  facet_grid(Region ~ pair, scales = "free") +
  labs(
    title = "Shock Characteristics by Region: Pairwise Comparisons",
    x = NULL, y = NULL, color = "Risk Type"
  ) +
  theme_bw(base_size = 13) +
  theme(
    strip.text = element_text(face = "bold"),
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold", hjust = 0.5)
  )

###

library(dplyr)
library(tidyr)
library(purrr)
library(ggplot2)
library(ggrepel)

## 1) Tag global + combine
comp_glob_tagged <- comp_glob_expand %>%
  mutate(Region = factor("Global")) %>%
  relocate(Region, .after = p.value)

comp_all_expand <- bind_rows(comp_reg_expand, comp_glob_tagged)

## 2) Summaries per Region × term × Risk_Type
comp_summary_all <- comp_all_expand %>%
  group_by(Region, term, Risk_Type) %>%
  summarise(
    avg_future = mean(real_est[Lag %in% 1:5],  na.rm = TRUE),
    avg_past   = mean(real_est[Lag %in% -5:-1], na.rm = TRUE),
    diff_future_past = avg_future - avg_past,
    lag_max = Lag[which.max(replace(real_est, is.na(real_est), -Inf))],
    .groups = "drop"
  )

## 3) Pairwise panels
pairs_long <- bind_rows(
  comp_summary_all %>%
    transmute(pair = "Avg Future vs Diff(Future − Past)",
              x = avg_future, y = diff_future_past,
              term, Risk_Type, Region),
  comp_summary_all %>%
    transmute(pair = "Avg Future vs Lag of Max",
              x = avg_future, y = lag_max,
              term, Risk_Type, Region),
  comp_summary_all %>%
    transmute(pair = "Diff(Future − Past) vs Lag of Max",
              x = diff_future_past, y = lag_max,
              term, Risk_Type, Region)
)

## 4) Compute GLOBAL |max| per variable (shared limits)
max_abs <- comp_summary_all %>%
  summarise(
    max_af   = max(abs(avg_future),       na.rm = TRUE),
    max_diff = max(abs(diff_future_past), na.rm = TRUE),
    max_lag  = max(abs(lag_max),          na.rm = TRUE)
  )

max_af   <- max_abs$max_af
max_diff <- max_abs$max_diff
max_lag  <- max_abs$max_lag
eps <- 1e-8
max_af   <- ifelse(max_af  > 0, max_af,  eps)
max_diff <- ifelse(max_diff> 0, max_diff,eps)
max_lag  <- ifelse(max_lag > 0, max_lag, eps)

## 5) Build facet limits from GLOBAL maxima (replicated for each Region × pair)
pair_defs <- tibble::tibble(
  pair  = c("Avg Future vs Diff(Future − Past)",
            "Avg Future vs Lag of Max",
            "Diff(Future − Past) vs Lag of Max"),
  x_lim = c(max_af, max_af, max_diff),
  y_lim = c(max_diff, max_lag, max_lag)
)

facet_limits <- tidyr::crossing(
  Region = distinct(pairs_long, Region)$Region,
  pair   = pair_defs$pair
) %>%
  left_join(pair_defs, by = "pair") %>%
  mutate(corners = map2(x_lim, y_lim, ~
                          tibble(x = c(-.x,  .x, -.x,  .x),
                                 y = c(-.y, -.y,  .y,  .y))
  )) %>%
  unnest(corners)

## 6) Plot: Region (rows) × Pair (cols), axes fixed by GLOBAL maxima
ggplot(pairs_long, aes(x = x, y = y, color = Risk_Type, label = term)) +
  geom_blank(data = facet_limits, inherit.aes = FALSE, aes(x = x, y = y)) +  # enforce limits
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey60") +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey60") +
  geom_point(size = 3, alpha = 0.9) +
  geom_text_repel(size = 3, show.legend = FALSE, max.overlaps = Inf) +
  facet_grid(Region ~ pair, scales = "free") +
  scale_x_continuous(expand = expansion(mult = 0)) +  # exact ±global max per variable
  scale_y_continuous(expand = expansion(mult = 0)) +
  labs(
    title = "Shock Characteristics by Region: Pairwise Comparisons",
    x = NULL, y = NULL, color = "Risk Type"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    strip.text = element_text(face = "bold"),
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold", hjust = 0.5)
  )





#################



library(dplyr)
library(tidyr)
library(purrr)
library(ggplot2)
library(ggrepel)

## 1) Tag global + combine
comp_glob_tagged <- comp_glob_expand %>%
  mutate(Region = factor("Global")) %>%
  relocate(Region, .after = p.value)

comp_all_expand <- bind_rows(comp_reg_expand, comp_glob_tagged)

## 2) Summaries per Region × term × Risk_Type
comp_summary_all <- comp_all_expand %>%
  group_by(Region, term, Risk_Type) %>%
  summarise(
    avg_future = mean(real_est[Lag %in% 1:5],  na.rm = TRUE),
    avg_past   = mean(real_est[Lag %in% -5:-1], na.rm = TRUE),
    diff_future_past = avg_future - avg_past,
    lag_max = Lag[which.max(replace(real_est, is.na(real_est), -Inf))],
    .groups = "drop"
  )

## 3) Pairwise panels
pairs_long <- bind_rows(
  comp_summary_all %>%
    transmute(pair = "Avg Future vs Diff(Future − Past)",
              x = avg_future, y = diff_future_past,
              term, Risk_Type, Region),
  comp_summary_all %>%
    transmute(pair = "Avg Future vs Lag of Max",
              x = avg_future, y = lag_max,
              term, Risk_Type, Region),
  comp_summary_all %>%
    transmute(pair = "Diff(Future − Past) vs Lag of Max",
              x = diff_future_past, y = lag_max,
              term, Risk_Type, Region)
)

## 4) Compute GLOBAL |max| per variable (shared limits)
max_abs <- comp_summary_all %>%
  summarise(
    max_af   = max(abs(avg_future),       na.rm = TRUE),
    max_diff = max(abs(diff_future_past), na.rm = TRUE),
    max_lag  = max(abs(lag_max),          na.rm = TRUE)
  )

max_af   <- max_abs$max_af
max_diff <- max_abs$max_diff
max_lag  <- max_abs$max_lag
eps <- 1e-8
max_af   <- ifelse(max_af  > 0, max_af,  eps)
max_diff <- ifelse(max_diff> 0, max_diff,eps)
max_lag  <- ifelse(max_lag > 0, max_lag, eps)

## 5) Build facet limits from GLOBAL maxima (replicated for each Region × pair)
pair_defs <- tibble::tibble(
  pair  = c("Avg Future vs Diff(Future − Past)",
            "Avg Future vs Lag of Max",
            "Diff(Future − Past) vs Lag of Max"),
  x_lim = c(max_af, max_af, max_diff),
  y_lim = c(max_diff, max_lag, max_lag)
)

facet_limits <- tidyr::crossing(
  Region = distinct(pairs_long, Region)$Region,
  pair   = pair_defs$pair
) %>%
  left_join(pair_defs, by = "pair") %>%
  mutate(corners = map2(x_lim, y_lim, ~
                          tibble(x = c(-.x,  .x, -.x,  .x),
                                 y = c(-.y, -.y,  .y,  .y))
  )) %>%
  unnest(corners)

## 6) Plot: Region (rows) × Pair (cols), axes fixed by GLOBAL maxima
ggplot(pairs_long, aes(x = x, y = y, color = Risk_Type, label = term)) +
  geom_blank(data = facet_limits, inherit.aes = FALSE, aes(x = x, y = y)) +  # enforce limits
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey60") +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey60") +
  geom_point(size = 3, alpha = 0.9) +
  geom_text_repel(size = 3, show.legend = FALSE, max.overlaps = Inf) +
  facet_grid(Region ~ pair, scales = "free") +
  scale_x_continuous(expand = expansion(mult = 0)) +  # exact ±global max per variable
  scale_y_continuous(expand = expansion(mult = 0)) +
  labs(
    title = "Shock Characteristics by Region: Pairwise Comparisons",
    x = NULL, y = NULL, color = "Risk Type"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    strip.text = element_text(face = "bold"),
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold", hjust = 0.5)
  )



####


# ---- Shock characteristics: three separate ggplots (regions as columns) ----
# Produces:
#   p_af_diff   : Avg Future vs Diff(Future−Past)
#   p_af_lag    : Avg Future vs Lag of Max
#   p_diff_lag  : Diff(Future−Past) vs Lag of Max
# You can later combine with patchwork or cowplot.

# ---- Libraries ----
library(dplyr)
library(ggplot2)
library(ggrepel)

# ---- 1) Tag Global + combine with regional data ----
comp_glob_tagged <- comp_glob_expand %>%
  mutate(Region = factor("Global")) %>%
  relocate(Region, .after = p.value)

comp_all_expand <- bind_rows(comp_reg_expand, comp_glob_tagged)

# (Optional) control Region order in the facets:
# comp_all_expand <- comp_all_expand %>%
#   mutate(Region = factor(Region, levels = c("HIC","MIC","LIC","Global")))

# ---- 2) Per-Region × term × Risk_Type summaries ----
#comp_summary_all <- comp_all_expand %>%
#  group_by(Region, term, Risk_Type) %>%
#  summarise(
#    avg_future = mean(real_est[Lag %in% 1:5],  na.rm = TRUE),
#    avg_past   = mean(real_est[Lag %in% -5:-1], na.rm = TRUE),
#    diff_future_past = avg_future - avg_past,
#    lag_max = {
#      v <- real_est
#      if (all(is.na(v))) NA_integer_ else Lag[which.max(replace(v, is.na(v), -Inf))]
#    },
#    .groups = "drop"
#  )


comp_summary_all <- comp_all_expand %>%
  group_by(Region, term, Risk_Type) %>%
  reframe({
    # mask for future lags
    fut_mask <- Lag %in% 1:5
    # replace non-future (or NA) with -Inf so which.max ignores them
    v_future <- ifelse(fut_mask, real_est, -Inf)
    
    if (!any(is.finite(v_future))) {
      # no usable future values in this group
      tibble(
        lag_max                  = NA_integer_,
        max_future               = NA_real_,
        corr_past                = NA_real_,
        diff_future_corrpast     = NA_real_
      )
    } else {
      i <- which.max(v_future)              # index of max among future lags
      lag_pos <- Lag[i]                     # positive lag (1..5)
      max_fut <- real_est[i]                # value at that future lag
      
      # value at the corresponding negative lag (e.g., -lag_pos)
      j <- which(Lag == -lag_pos)
      past_val <- if (length(j)) real_est[j[1]] else NA_real_
      
      tibble(
        lag_max              = lag_pos,                 # future lag of the max future value
        max_future           = max_fut,                 # max value among lags 1..5
        corr_past            = past_val,                # value at -lag_max (may be NA if missing)
        diff_future_corrpast = max_fut - past_val       # comparison metric
      )
    }
  })



### plot order of region levels

comp_summary_all$Region<-factor(comp_summary_all$Region,levels=c("Global","HIC","UMC","LMC","LIC")) 

# ---- 3) Global symmetric limits per variable (shared across all plots/facets) ----
eps      <- 1e-8
max_af   <- max(abs(comp_summary_all$max_future),       na.rm = TRUE); max_af   <- ifelse(max_af   > 0, max_af,   eps)
max_diff <- max(abs(comp_summary_all$diff_future_corrpast), na.rm = TRUE); max_diff <- ifelse(max_diff > 0, max_diff, eps)
max_lag  <- max(abs(comp_summary_all$lag_max),          na.rm = TRUE); max_lag  <- ifelse(max_lag  > 0, max_lag,  eps)


x11()
future_skill_gg<-ggplot(
  comp_summary_all,
  aes(x = max_future, y = diff_future_corrpast, color = Risk_Type)
)+geom_line(lty="dashed")+geom_point(aes(shape = Region),size=2)+theme_bw()+
  geom_hline(yintercept = 0, color = "grey60") +
  geom_vline(xintercept = 0, color = "grey60")+
  scale_x_continuous(limits = c(-max_af,   max_af),   expand = expansion(mult = 0.05)) +
  scale_y_continuous(limits = c(-max_diff, max_diff), expand = expansion(mult = 0.05))+
ylab("Anticipatory skill (future-past)")+xlab("Predictive capacity (max future)")
print(future_skill_gg)


#x11()
#max_lag_gg<-ggplot(
#  comp_summary_all,
#  aes(x = avg_future, y = lag_max, color = Risk_Type)
#)+geom_line(lty="dashed")+geom_point(aes(shape = Region),size=2)+theme_bw()+
#  geom_hline(yintercept = 0, color = "grey60") +
#  geom_vline(xintercept = 0, color = "grey60")+
#  scale_x_continuous(limits = c(-max_af,   max_af),   expand = expansion(mult = 0.05)) +
#  scale_y_continuous(limits = c(-max_lag, max_lag), expand = expansion(mult = 0.05))
#
#print(max_lag_gg)


x11()
max_futurelag_gg<-ggplot(
  comp_summary_all,
  aes(x = lag_max, y = diff_future_corrpast, color = Risk_Type)
)+geom_line(lty="dashed")+geom_point(aes(shape = Region),size=2)+theme_bw()+
  geom_hline(yintercept = 0, color = "grey60") +
  #geom_vline(xintercept = 0, color = "grey60")+
  #scale_x_continuous(limits = c(0,   max_lag),   expand = expansion(mult = 0)) +
  #scale_y_continuous(limits = c(-max_diff, max_diff), expand = expansion(mult = 0.05))+
  ylab("Anticipatory skill (future-past)")+xlab("Time horizon (years)")+
  xlim(c(0,5))+ylim(-1.6,1.6)#+ylim(c(-1*max(abs(diff_future_corrpast)),max(abs(diff_future_corrpast))))

print(max_futurelag_gg)

combined <- (future_skill_gg | max_futurelag_gg) + plot_annotation(title = "Shock Prediction Characteristics by Region")
x11()
print(combined)


# ---- 4) Helper to add common layers (regions as columns, centered axes, labels) ----
add_base_layers <- function(p) {
  p +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey60") +
    geom_vline(xintercept = 0, linetype = "dashed", color = "grey60") +
    geom_point(size = 3, alpha = 0.9) +
    #ggrepel::geom_text_repel(aes(label = term), size = 3, show.legend = FALSE, max.overlaps = Inf) +
    facet_wrap(~ Region, nrow = 1, scales = "free") +  # REGIONS AS COLUMNS
    theme_bw(base_size = 13) +
    theme(
      strip.text = element_text(face = "bold"),
      panel.grid.minor = element_blank()
    ) +
    labs(color = "Risk Type")
}

# ---- 5) Three separate plots ----

# (A) Avg Future vs Diff(Future − Past)
p_af_diff <- add_base_layers(
  ggplot(
    comp_summary_all,
    aes(x = avg_future, y = diff_future_past, color = Risk_Type)
  ) +
    scale_x_continuous(limits = c(-max_af,   max_af),   expand = expansion(mult = 0)) +
    scale_y_continuous(limits = c(-max_diff, max_diff), expand = expansion(mult = 0)) +
    labs(x = "Average Future Coefficient", y = "Difference (Future − Past)")
)

# (B) Avg Future vs Lag of Max
p_af_lag <- add_base_layers(
  ggplot(
    comp_summary_all,
    aes(x = avg_future, y = lag_max, color = Risk_Type)
  ) +
    scale_x_continuous(limits = c(-max_af,  max_af),  expand = expansion(mult = 0)) +
    scale_y_continuous(limits = c(-max_lag, max_lag), expand = expansion(mult = 0)) +
    labs(x = "Average Future Coefficient", y = "Lag of Maximum Coefficient")
)

# (C) Diff(Future − Past) vs Lag of Max
p_diff_lag <- add_base_layers(
  ggplot(
    comp_summary_all,
    aes(x = diff_future_past, y = lag_max, color = Risk_Type)
  ) +
    scale_x_continuous(limits = c(-max_diff, max_diff), expand = expansion(mult = 0)) +
    scale_y_continuous(limits = c(-max_lag,  max_lag),  expand = expansion(mult = 0)) +
    labs(x = "Difference (Future − Past)", y = "Lag of Maximum Coefficient")
)

# ---- 6) Print individually (uncomment to view) ----
# print(p_af_diff)
# print(p_af_lag)
# print(p_diff_lag)

# ---- 7) (Optional) Combine later with patchwork ----
# install.packages("patchwork")
 #library(patchwork)
 combined <- (p_af_diff / p_af_lag / p_diff_lag) + plot_annotation(title = "Shock Characteristics by Region")
 x11()
 print(combined)

