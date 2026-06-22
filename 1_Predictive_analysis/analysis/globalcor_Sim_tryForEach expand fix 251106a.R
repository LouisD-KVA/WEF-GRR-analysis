# ====================================================================
# Global risk–shock correlation with randomization simulation
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
library(doParallel)
library(foreach)
library(doRNG)

# ====================================================================
# ----------------------------- MAIN ---------------------------------
# ====================================================================

# ---- Paths ----
wd <- "C:\\Users\\psoga\\Cloud-Drive\\ESCAPE\\WEF"
setwd(wd)

# ====================================================================
# --------------------------- SOURCE FUNCTIONS -----------------------
# ====================================================================
source("sim_functions.r")  # must contain: make_shocks_global, smooth_nat_shocks, rand_shocks
# (This script defines two new small helpers used below.)

# ====================================================================
# ----------------------------- DATA ---------------------------------
# ====================================================================
risks   <- read.csv("Risks 251014.csv")  # old: "Risks.csv"
sh_nat  <- read.csv("Shock counts.csv")

# ---- Country ISO3 ----
sh_nat <- sh_nat %>%
  mutate(ISO3 = countrycode(Country.name, "country.name", "iso3c"))

# ---- Income groups (not used for global agg but harmless to keep) ----
meta <- wbstats::wb_cachelist$countries
inc_key <- meta %>% select(iso3c, income_level_iso3c)
sh_nat <- sh_nat %>%
  left_join(inc_key, by = c("ISO3" = "iso3c")) %>%
  rename(IncomeGroup = income_level_iso3c)

# ---- Cleaning ----
sh_nat <- sh_nat %>%
  filter(Shock.type != "Infestation",
         Year > (min(risks$Year) - 6)) %>%
  mutate(
    Shock.category = if_else(Shock.type == "Infectious disease" & Shock.category == "ECOLOGICAL",
                             "DISEASES", Shock.category),
    Shock.category = if_else(Shock.type == "Terrorist attack" & Shock.category == "CONFLICTS",
                             "TERRORISM", Shock.category)
  )

# ---- Category cutoffs ----
end_years <- tibble::tribble(
  ~Shock.category, ~LastYear,
  "ECOLOGICAL", 2013, "DISEASES", 2022, "CLIMATIC", 2024,
  "TECHNOLOGICAL", 2024, "GEOPHYSICAL", 2024,
  "TERRORISM", 2020, "CONFLICTS", 2023, "ECONOMIC", 2019
)
sh_nat <- sh_nat %>%
  left_join(end_years, by = "Shock.category") %>%
  filter(Year <= LastYear) %>%
  select(-LastYear)

# ---- Risks long ----
risks_long <- risks %>%
  pivot_longer(-Year, names_to = "Risk_Type", values_to = "Risk_Score")

# ---- Mapping shocks → risk names ----
map_risk <- c(
  "CLIMATIC"="Climate","GEOPHYSICAL"="Geophysical","ECOLOGICAL"="Food",
  "TECHNOLOGICAL"="Tech","CONFLICTS"="GeoConflict","ECONOMIC"="Economic",
  "DISEASES"="Diseases","TERRORISM"="Terror"
)

# ====================================================================
# ----------------- REAL DATA: expanding-window (GLOBAL) -------------
# ====================================================================

# Precompute smoothed & aggregated shocks for each lag window (1–5)
max_lag <- 5
smoothed_glob_sets <- purrr::map(1:max_lag, function(w) {
  message("Preparing smoothed global data for window = ", w)
  sh_tmp <- if (w == 1) sh_nat else smooth_nat_shocks(sh_nat, window = w)
  make_shocks_global(
    sh_tmp,
    method = "category_first",
    cutoff  = TRUE
  ) %>%
    mutate(Shock_Type = dplyr::recode(Shock_Type, !!!map_risk))
})
names(smoothed_glob_sets) <- paste0("lag", 1:max_lag)

# Run expanding-window regressions (GLOBAL)
rtypes_glob <- intersect(unique(risks_long$Risk_Type),
                         unique(smoothed_glob_sets$lag1$Shock_Type))

res_glob_expand_fast <- purrr::map_dfr(
  rtypes_glob,
  ~run_reg_expand_glob(
    rtype = .x,
    max_lag = max_lag,
    risks_long = risks_long,
    smoothed_glob_sets = smoothed_glob_sets,
    include0 = TRUE
  )
) %>% dplyr::filter(term == "Risk_Score")

save(res_glob_expand_fast, file = paste0("glob_expanding_res_", Sys.Date(), ".RData"))

# ====================================================================
# ---------------- SIMULATION (GLOBAL, parallel) ---------------------
# ====================================================================

n_sim_expand <- 1500
include0     <- TRUE
min_n        <- 5
n_workers    <- 10

# Cache randomized national shocks to disk (idempotent)
dir.create("rand_glob_cache", showWarnings = FALSE)
existing <- length(list.files("rand_glob_cache", pattern = "^rand_\\d{4}\\.rds$"))
if (existing < n_sim_expand) {
  message("Generating ", n_sim_expand - existing, " randomisations...")
  purrr::walk((existing + 1):n_sim_expand, \(i) {
    sh_sim <- rand_shocks(sh_nat)
    saveRDS(sh_sim, file = file.path("rand_glob_cache", sprintf("rand_%04d.rds", i)))
  })
}
# Top-up with seeded new ones (optional)
base_seed  <- 20251106
target_n   <- 1500
start_from <- existing + 1
if (start_from <= target_n) {
  purrr::walk(start_from:target_n, \(i) {
    set.seed(base_seed + i)
    sh_sim <- rand_shocks(sh_nat)
    saveRDS(sh_sim, file = file.path("rand_glob_cache", sprintf("rand_%04d.rds", i)))
  })
}
rand_files <- list.files("rand_glob_cache", full.names = TRUE, pattern = "^rand_\\d{4}\\.rds$")
message("📦 Total randomisations available: ", length(rand_files))

# 10 workers, one lag each (no lag 0)
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

# Choose which randomisation files to use (example slice)
rand_files_subset <- rand_files[1001:1500]

# Log after every X randomisation files per worker
progress_every <- 100  # <-- adjust as you like

# Parallel run
Sys.setenv(OMP_NUM_THREADS=1, MKL_NUM_THREADS=1, OPENBLAS_NUM_THREADS=1, BLIS_NUM_THREADS=1)
cl <- parallel::makeCluster(min(n_workers, length(lag_groups)))
doParallel::registerDoParallel(cl)
registerDoRNG(123)
dir.create("logs_glob", showWarnings = FALSE)

parallel::clusterEvalQ(cl, { library(dplyr); library(tidyr); library(purrr); library(broom) })
parallel::clusterExport(
  cl,
  varlist = c(
    # helpers
    "run_lag_worker_glob", "run_reg_expand_glob",
    "make_shocks_global", "smooth_nat_shocks", "rand_shocks",
    # data
    "sh_nat", "rand_files_subset", "risks_long", "map_risk",
    # args
    "include0", "min_n", "progress_every"   # <-- added
  ),
  envir = .GlobalEnv
)

time.start <- Sys.time()
res_glob_lag_parallel <- foreach(
  g = seq_along(lag_groups),
  .combine  = dplyr::bind_rows,
  .inorder  = FALSE,
  .packages = c("dplyr","tidyr","purrr","broom")
) %dopar% {
  pid <- Sys.getpid()
  log_file <- file.path("logs_glob", sprintf("glob_worker_%s_group_%s.log", pid, g))
  cat(format(Sys.time(), "%H:%M:%S"), "| start group", g, "lags:",
      paste(lag_groups[[g]], collapse = ","), "\n", file = log_file, append = TRUE)
  
  out <- run_lag_worker_glob(
    lag_set    = lag_groups[[g]],
    sh_nat     = sh_nat,
    rand_files = rand_files_subset,
    risks_long = risks_long,
    map_risk   = map_risk,
    include0   = include0,
    min_n      = min_n,
    log_file   = log_file,        # <-- added
    progress_every = progress_every  # <-- added
  )
  
  cat(format(Sys.time(), "%H:%M:%S"), "| done group", g, "rows:", nrow(out), "\n",
      file = log_file, append = TRUE)
  out
}
parallel::stopCluster(cl); gc()

print(Sys.time() - time.start)

#res_glob_lag_parallel_1000<-res_glob_lag_parallel
res_glob_lag_parallel_1500<-res_glob_lag_parallel
save(res_glob_lag_parallel, file = paste0("glob_expanding_sim_1001_1500_", length(rand_files_subset), "_", Sys.Date(), ".RData"))


res_glob_lag_parallel<-rbind(res_glob_lag_parallel_1000,res_glob_lag_parallel_1500)

# ====================================================================
# ------------------- SUMMARIES & COMPARISON (GLOBAL) ----------------
# ====================================================================

# Sim summaries (GLOBAL: no Region column)
sim_expand_glob_sum <- res_glob_lag_parallel %>%
  group_by(Risk_Type, Lag) %>%
  summarise(
    mean_sim = mean(estimate, na.rm = TRUE),
    sd_sim   = sd(estimate, na.rm = TRUE),
    q05      = quantile(estimate, 0.05, na.rm = TRUE),
    q95      = quantile(estimate, 0.95, na.rm = TRUE),
    .groups  = "drop"
  )

comp_glob_expand <- res_glob_expand_fast %>%
  filter(term == "Risk_Score") %>%
  rename(real_est = estimate) %>%
  left_join(sim_expand_glob_sum, by = c("Risk_Type", "Lag")) %>%
  mutate(
    z = (real_est - mean_sim) / sd_sim,
    signif = real_est < q05 | real_est > q95
  ) %>%
  mutate(
    sig.two = case_when(
      signif & p.value < 0.05 ~ "BOTH",
      signif & p.value >= 0.05 ~ "SIM",
      !signif & p.value < 0.05 ~ "REG",
      TRUE ~ "NONE"
    )
  )

comp_glob_expand$sig.two <- factor(comp_glob_expand$sig.two, levels = c("BOTH","SIM","REG","NONE"))
comp_glob_expand$Risk_Type <- factor(comp_glob_expand$Risk_Type,
                                     levels = c("Geophysical","Climate","Diseases","Food","Economic","GeoConflict","Terror","Tech"))

# Plot (GLOBAL)
x11()
ggplot(comp_glob_expand, aes(x = Lag, y = real_est)) +
  geom_ribbon(aes(ymin = q05, ymax = q95), fill = "grey80", alpha = 0.4) +
  geom_point(aes(colour = sig.two), size = 2) +
  geom_line(alpha = 0.5) +
  facet_wrap(~ Risk_Type, ncol = 4) +
  labs(y = "Coefficient (observed shocks vs. simulated 5–95%)",
       x = "Max lag (years)", colour = "Significant (5%)") +
  geom_hline(yintercept = 0) + geom_vline(xintercept = 0) +
  theme_bw()



# Compute summary measures per term and risk type (one region = global)
comp_summary <- comp_glob_expand %>%
  group_by(term, Risk_Type) %>%
  summarise(
    avg_future = mean(real_est[Lag %in% 1:5], na.rm = TRUE),
    avg_past   = mean(real_est[Lag %in% -5:-1], na.rm = TRUE),
    diff_future_past = avg_future - avg_past,
    lag_max = Lag[which.max(real_est)],
    .groups = "drop"
  )

