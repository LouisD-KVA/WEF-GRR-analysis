### sim functions WEF analysis

### expanding time window with increasing lag

# ====================================================================
# Fast version using cached smoothed data per lag width
# ====================================================================
# ====================================================================
# Fast expanding-window regression (uses cached smoothed datasets)
# ====================================================================



run_reg_expand_reg <- function(region, rtype,
                               max_lag = 5,
                               risks_long,
                               smoothed_reg_sets,
                               include0 = TRUE,
                               min_n = 5) {
  
  # --- Filter relevant data -----------------------------------------
  r_filt <- risks_long %>%
    filter(Risk_Type == rtype) %>%
    rename(Risk_Year = Year)
  
  lags <- seq(-max_lag, max_lag)
  
  purrr::map_dfr(lags, function(l) {
    width <- abs(l)
    
    # --- Skip lag 0 --------------------------------------------------
    if (width == 0) {
      message("Skipping lag 0 (no regression window)")
      return(NULL)
    }
    
    # --- Defensive check for missing lag dataset --------------------
    lag_name <- paste0("lag", width)
    if (!lag_name %in% names(smoothed_reg_sets) ||
        is.null(smoothed_reg_sets[[lag_name]])) {
      message("⚠️ Missing smoothed dataset for ", lag_name, 
              " in region ", region, " / ", rtype)
      return(NULL)
    }
    
    # --- Extract relevant subset ------------------------------------
    s_tmp <- smoothed_reg_sets[[lag_name]] %>%
      filter(Region == region, Shock_Type == rtype) %>%
      rename(Shock_Year = Year)
    
    # --- Merge with risk data ---------------------------------------
    merged <- r_filt %>%
      rowwise() %>%
      mutate(
        Avg_Shock = {
          offsets <- if (l < 0) (-width:-1) else (1:width)
          years <- Risk_Year + offsets
          if (include0) years <- c(Risk_Year, years)
          
          vals <- s_tmp %>%
            filter(Shock_Year %in% years) %>%
            pull(Shock_Occ)
          if (length(vals) == 0) NA_real_ else mean(vals, na.rm = TRUE)
        }
      ) %>%
      ungroup() %>%
      filter(!is.na(Avg_Shock))
    
    # --- Handle small sample sizes safely ---------------------------
    if (nrow(merged) < min_n) {
      return(tibble(
        term = "Risk_Score",
        estimate = NA_real_,
        std.error = NA_real_,
        statistic = NA_real_,
        p.value = NA_real_,
        Region = region,
        Risk_Type = rtype,
        Lag = l,
        N = nrow(merged)
      ))
    }
    
    # --- Run regression ---------------------------------------------
    mod <- lm(Avg_Shock ~ Risk_Score, data = merged)
    broom::tidy(mod) %>%
      mutate(Region = region,
             Risk_Type = rtype,
             Lag = l,
             N = nrow(merged))
  })
}


##### simulation with expanding window

## ====================================================================
# --- Simulation: Expanding-window regressions on randomized shocks --
# ====================================================================
# ====================================================================
# Fast expanding-window simulation (uses cached smoothed datasets)
# ====================================================================

run_sim_expand_reg <- function(i, sh_nat, reg_key, risks_long,
                               map_risk,
                               max_lag = 5,
                               reg_level = c("income", "custom"),
                               include0 = TRUE, min_n = 5) {
  reg_level <- match.arg(reg_level)
  message("Simulation ", i)
  
  # 1. Randomize shocks
  sh_sim <- rand_shocks(sh_nat)
  
  # 2. Precompute smoothed + aggregated sets for this randomized data
  smoothed_sets_sim <- purrr::map(1:max_lag, function(w) {
    sh_tmp <- if (w == 1) sh_sim else smooth_nat_shocks(sh_sim, window = w)
    make_shocks_reg(
      sh_tmp, reg_key,
      method = "category_first",
      reg_level = reg_level,
      cutoff = TRUE
    ) %>%
      mutate(Shock_Type = recode(Shock_Type, !!!map_risk))
  })
  names(smoothed_sets_sim) <- paste0("lag", 1:max_lag)
  
  # 3. Run regressions using these smoothed versions (per simulation)
  regs <- unique(smoothed_sets_sim$lag1$Region)
  rtypes <- intersect(unique(risks_long$Risk_Type),
                      unique(smoothed_sets_sim$lag1$Shock_Type))
  
  purrr::pmap_dfr(
    expand_grid(Region = regs, Risk_Type = rtypes),
    function(Region, Risk_Type) {
      run_reg_expand_reg(
        region = Region,
        rtype = Risk_Type,
        max_lag = max_lag,
        risks_long = risks_long,
        smoothed_reg_sets = smoothed_sets_sim,
        include0 = include0,
        min_n = min_n
      )
    }
  ) %>%
    filter(term == "Risk_Score") %>%
    mutate(Sim = i)
}

### SMOOTHING NATIONAL TIME SERIES

smooth_nat_shocks <- function(sh_nat, window = 5) {
  requireNamespace("zoo", quietly = TRUE)
  
  # Ensure missing years have zeros
  grid_all <- expand_grid(
    ISO3 = unique(sh_nat$ISO3),
    Year = unique(sh_nat$Year),
    Shock.type = unique(sh_nat$Shock.type),
    Shock.category = unique(sh_nat$Shock.category)
  )
  
  sh_full <- sh_nat %>%
    right_join(grid_all, by = c("ISO3", "Year", "Shock.type", "Shock.category")) %>%
    mutate(count = replace_na(count, 0))
  
  # Smooth the actual count column
  sh_full %>%
    group_by(ISO3, Shock.type, Shock.category) %>%
    arrange(Year) %>%
    mutate(count = zoo::rollmean(count, k = window, fill = NA, align = "center")) %>%
    ungroup()
}

#smooth_nat_shocks <- function(sh_nat, window = 5) {
#  half <- floor(window / 2)
#  sh_nat %>%
#    group_by(ISO3, Shock.type, Shock.category) %>%
#    arrange(Year) %>%
#    mutate(count_smooth = zoo::rollmean(count, k = window, fill = NA, align = "center")) %>%
#    ungroup()
#}


# ====================================================================
# ----------- ANNUAL (YEAR-BY-YEAR) REGIONAL FUNCTIONS ---------------
# ====================================================================

# ---- 1. Annual regression per region and lag -----------------------
run_reg_annual_reg <- function(region, rtype, max_lag = 5,
                               risks_long, shocks_reg) {
  
  r_filt <- risks_long %>%
    filter(Risk_Type == rtype) %>%
    rename(Risk_Year = Year)
  
  s_filt <- shocks_reg %>%
    filter(Region == region, Shock_Type == rtype) %>%
    rename(Shock_Year = Year)
  
  lags <- seq(-max_lag, max_lag)
  
  purrr::map_dfr(lags, function(l) {
    merged <- r_filt %>%
      mutate(Shock_Year = Risk_Year + l) %>%
      left_join(s_filt, by = "Shock_Year") %>%
      filter(!is.na(Risk_Score), !is.na(Shock_Occ))
    
    if (nrow(merged) < 5) return(NULL)
    
    mod <- lm(Shock_Occ ~ Risk_Score, data = merged)
    broom::tidy(mod) %>%
      mutate(Region = region,
             Risk_Type = rtype,
             Lag = l,
             N = nrow(merged))
  })
}


# ---- 2. One simulation iteration (regional annual) -----------------
run_sim_annual_reg <- function(i, sh_nat, reg_key, risks_long,
                               map_risk, max_lag = 5,
                               reg_level = c("income", "custom"),
                               smooth = FALSE, window = 5) {
  reg_level <- match.arg(reg_level)
  message("Regional annual simulation ", i)
  
  # Randomize shocks within-country
  sh_sim <- rand_shocks(sh_nat)
  
  # Optional smoothing (at national level, before aggregation)
  if (smooth) {
    message("  Applying ", window, "-year moving average smoothing...")
    sh_sim <- smooth_nat_shocks(sh_sim, window = window)
  }
  
  # Aggregate to regional level
  sh_reg <- make_shocks_reg(
    sh_sim, reg_key,
    method = "category_first",
    reg_level = reg_level,
    cutoff = TRUE
  ) %>%
    mutate(Shock_Type = recode(Shock_Type, !!!map_risk))
  
  regs <- unique(sh_reg$Region)
  rtypes <- intersect(unique(risks_long$Risk_Type),
                      unique(sh_reg$Shock_Type))
  
  purrr::pmap_dfr(
    expand_grid(Region = regs, Risk_Type = rtypes),
    function(Region, Risk_Type) {
      run_reg_annual_reg(Region, Risk_Type,
                         max_lag = max_lag,
                         risks_long = risks_long,
                         shocks_reg = sh_reg)
    }
  ) %>%
    filter(term == "Risk_Score") %>%
    mutate(Sim = i)
}


##### YEAR-BY-YEAR GLOBAL ANALYSIS

# ====================================================================
# ----------- ANNUAL (YEAR-BY-YEAR) GLOBAL FUNCTIONS -----------------
# ====================================================================

# ---- 1. Annual regression by lag ----------------------------------
run_reg_annual <- function(rtype, max_lag = 5, risks_long, shocks_glob) {
  # Filter data for this risk type
  r_filt <- risks_long %>%
    filter(Risk_Type == rtype) %>%
    rename(Risk_Year = Year)
  
  s_filt <- shocks_glob %>%
    filter(Shock_Type == rtype) %>%
    rename(Shock_Year = Year)
  
  # Define lags to test
  lags <- seq(-max_lag, max_lag)
  
  purrr::map_dfr(lags, function(l) {
    merged <- r_filt %>%
      mutate(Shock_Year = Risk_Year + l) %>%       # define lagged shock year
      left_join(s_filt, by = "Shock_Year") %>%     # join corresponding shock value
      filter(!is.na(Risk_Score), !is.na(Shock_Occ))
    
    if (nrow(merged) < 5) return(NULL)
    
    mod <- lm(Shock_Occ ~ Risk_Score, data = merged)
    broom::tidy(mod) %>%
      mutate(Risk_Type = rtype,
             Lag = l,
             N = nrow(merged))
  })
}


# ---- 2. One simulation iteration (annual version) ------------------
run_sim_annual <- function(i, sh_nat, risks_long, map_risk,
                           max_lag = 5) {
  message("Annual simulation ", i)
  
  # Randomize within-country
  sh_sim <- rand_shocks(sh_nat)
  
  # Aggregate to global
  sh_glob <- make_shocks_global(
    sh_sim,
    method = "category_first",
    cutoff = TRUE
  ) %>%
    mutate(Shock_Type = recode(Shock_Type, !!!map_risk))
  
  rtypes <- intersect(unique(risks_long$Risk_Type),
                      unique(sh_glob$Shock_Type))
  
  purrr::map_dfr(rtypes, function(risk) {
    run_reg_annual(risk, max_lag = max_lag,
                   risks_long = risks_long,
                   shocks_glob = sh_glob)
  }) %>%
    filter(term == "Risk_Score") %>%
    mutate(Sim = i)
}


#### 5-YEAR WINDOW GLOBAL ANALYSIS


# ---- 0. global aggregration of shocks

# ====================================================================
# ----------- GLOBAL-LEVEL ANALYSIS FUNCTIONS ------------------------
# ====================================================================

# ---- 1. Aggregate shocks to global level ---------------------------

# ---- Aggregate shocks globally (matching regional logic) -----------
make_shocks_global <- function(sh_nat,
                               method = c("type_first","category_first"),
                               cutoff = TRUE) {
  method <- match.arg(method)
  
  types_all <- unique(sh_nat$Shock.type)
  cats_all  <- unique(sh_nat$Shock.category)
  
  # ----- Build year grid respecting cutoffs -----
  if (cutoff) {
    cut_years <- c(
      "CLIMATIC"     = 2024, "GEOPHYSICAL" = 2024,
      "ECOLOGICAL"   = 2013, "DISEASES" = 2022,
      "TECHNOLOGICAL"= 2024, "CONFLICTS" = 2023,
      "TERRORISM"    = 2020, "ECONOMIC" = 2019
    )
    grid_nat <- purrr::map_dfr(cats_all, function(cat) {
      last_year <- cut_years[[cat]] %||% max(sh_nat$Year, na.rm = TRUE)
      yrs <- sort(unique(sh_nat$Year[sh_nat$Year <= last_year]))
      expand_grid(
        Year = yrs,
        Shock.type = unique(sh_nat$Shock.type[sh_nat$Shock.category == cat]),
        Shock.category = cat
      )
    })
  } else {
    yrs_all <- sort(unique(sh_nat$Year))
    grid_nat <- expand_grid(Year = yrs_all,
                            Shock.type = types_all,
                            Shock.category = cats_all)
  }
  
  # ----- Fill counts (ensure full time grid) -----
  sh_full <- sh_nat %>%
    group_by(Year, Shock.type, Shock.category) %>%
    summarise(count = sum(count, na.rm = TRUE), .groups = "drop") %>%
    right_join(grid_nat, by = c("Year","Shock.type","Shock.category")) %>%
    mutate(count = replace_na(count, 0))
  
  # ----- Standardize -----
  if (method == "type_first") {
    sh_std <- sh_full %>%
      group_by(Shock.type) %>%
      mutate(sd_val = sd(count, na.rm = TRUE),
             count_std = ifelse(sd_val == 0, 0, count / sd_val)) %>%
      ungroup()
    sh_glob <- sh_std %>%
      group_by(Year, Shock.category) %>%
      summarise(Shock_Occ = sum(count_std, na.rm = TRUE), .groups = "drop")
  } else {
    sh_cat <- sh_full %>%
      group_by(Year, Shock.category) %>%
      summarise(count = sum(count, na.rm = TRUE), .groups = "drop")
    sh_glob <- sh_cat %>%
      group_by(Shock.category) %>%
      mutate(sd_val = sd(count, na.rm = TRUE),
             Shock_Occ = ifelse(sd_val == 0, 0, count / sd_val)) %>%
      ungroup()
  }
  
  sh_glob %>% rename(Shock_Type = Shock.category)
}


# ---- 2. Global regression function ---------------------------------
run_reg_glob <- function(rtype, lag_label, s_off, e_off, risks_long, shocks_glob) {
  r_filt <- risks_long %>% filter(Risk_Type == rtype) %>% rename(Risk_Year = Year)
  s_filt <- shocks_glob %>% filter(Shock_Type == rtype) %>% rename(Shock_Year = Year)
  
  merged <- r_filt %>%
    rowwise() %>%
    mutate(
      sh_start = Risk_Year + s_off,
      sh_end   = Risk_Year + e_off,
      avg_shock = {
        vals <- s_filt %>%
          filter(Shock_Year >= sh_start, Shock_Year <= sh_end) %>%
          pull(Shock_Occ)
        if (length(vals) == (e_off - s_off + 1)) mean(vals, na.rm = TRUE) else NA_real_
      }
    ) %>%
    ungroup() %>%
    filter(!is.na(avg_shock))
  
  if (nrow(merged) < 5) return(NULL)
  mod <- lm(avg_shock ~ Risk_Score, data = merged)
  tidy(mod) %>%
    mutate(Risk_Type = rtype, Lag = lag_label, N = nrow(merged))
}


# ---- 3. One global simulation iteration ----------------------------
run_sim_glob <- function(i, sh_nat, risks_long, lag_win, map_risk) {
  message("Global simulation ", i)
  
  sh_sim <- rand_shocks(sh_nat)
  
  sh_glob <- make_shocks_global(sh_sim, "category_first", cutoff = TRUE) %>%
    mutate(Shock_Type = recode(Shock_Type, !!!map_risk))
  
  rtypes <- intersect(unique(risks_long$Risk_Type), unique(sh_glob$Shock_Type))
  
  purrr::pmap_dfr(
    expand_grid(Risk_Type = rtypes, lag_win),
    function(Risk_Type, Lag_Label, Start_Offset, End_Offset) {
      run_reg_glob(Risk_Type, Lag_Label, Start_Offset, End_Offset, risks_long, sh_glob)
    }
  ) %>%
    filter(term == "Risk_Score") %>%
    mutate(Sim = i)
}



# ---- 1. Aggregate shocks to regions --------------------------------
make_shocks_reg <- function(sh_nat, reg_key,
                            method = c("type_first","category_first"),
                            reg_level = c("custom","income"),
                            cutoff = TRUE) {
  method <- match.arg(method)
  reg_level <- match.arg(reg_level)
  
  # ----- Choose regional grouping -----
  if (reg_level == "custom") {
    sh_with_reg <- sh_nat %>%
      left_join(reg_key, by = "ISO3") %>%
      rename(RegGrp = Region)
  } else {
    if (!"IncomeGroup" %in% names(sh_nat)) stop("Missing IncomeGroup column")
    sh_with_reg <- sh_nat %>% mutate(RegGrp = IncomeGroup)
  }
  
  regs_all <- unique(sh_with_reg$RegGrp)
  types_all <- unique(sh_nat$Shock.type)
  cats_all  <- unique(sh_nat$Shock.category)
  
  # ----- Build year grid respecting category cutoffs -----
  if (cutoff) {
    cut_years <- c(
      "CLIMATIC"      = 2024, "GEOPHYSICAL" = 2024,
      "ECOLOGICAL"    = 2013, "DISEASES"    = 2022,
      "TECHNOLOGICAL" = 2024, "CONFLICTS"   = 2023,
      "TERRORISM"     = 2020, "ECONOMIC"    = 2019
    )
    grid_nat <- purrr::map_dfr(cats_all, function(cat) {
      last_year <- cut_years[[cat]] %||% max(sh_nat$Year, na.rm = TRUE)
      yrs <- sort(unique(sh_nat$Year[sh_nat$Year <= last_year]))
      expand_grid(RegGrp = regs_all, Year = yrs,
                  Shock.type = unique(sh_nat$Shock.type[sh_nat$Shock.category == cat]),
                  Shock.category = cat)
    })
  } else {
    yrs_all <- sort(unique(sh_nat$Year))
    grid_nat <- expand_grid(RegGrp = regs_all, Year = yrs_all,
                            Shock.type = types_all, Shock.category = cats_all)
  }
  
  # ----- Fill counts -----
  sh_full <- sh_with_reg %>%
    group_by(RegGrp, Year, Shock.type, Shock.category) %>%
    summarise(count = sum(count, na.rm = TRUE), .groups = "drop") %>%
    right_join(grid_nat, by = c("RegGrp","Year","Shock.type","Shock.category")) %>%
    mutate(count = replace_na(count, 0))
  
  # ----- Standardize -----
  if (method == "type_first") {
    sh_std <- sh_full %>%
      group_by(RegGrp, Shock.type) %>%
      mutate(sd_val = sd(count, na.rm = TRUE),
             count_std = ifelse(sd_val == 0, 0, count / sd_val)) %>%
      ungroup()
    sh_reg <- sh_std %>%
      group_by(RegGrp, Year, Shock.category) %>%
      summarise(Shock_Occ = sum(count_std, na.rm = TRUE), .groups = "drop")
  } else {
    sh_cat <- sh_full %>%
      group_by(RegGrp, Year, Shock.category) %>%
      summarise(count = sum(count, na.rm = TRUE), .groups = "drop")
    sh_reg <- sh_cat %>%
      group_by(RegGrp, Shock.category) %>%
      mutate(sd_val = sd(count, na.rm = TRUE),
             Shock_Occ = ifelse(sd_val == 0, 0, count / sd_val)) %>%
      ungroup()
  }
  
  # ----- Rename + remove missing regions -----
  sh_reg <- sh_reg %>%
    rename(Shock_Type = Shock.category, Region = RegGrp) %>%
    filter(!is.na(Region))   # <---- drop rows with missing region assignment
  
  return(sh_reg)
}


## ---- 2. Randomize shocks within each country -----------------------
#rand_shocks <- function(sh_nat) {
#  sh_nat %>%
#    group_by(ISO3, Shock.type, Shock.category) %>%
#    mutate(Year = sample(Year, length(Year), replace = FALSE)) %>%
#    ungroup()
#}

# ---- 2. Randomize shocks after zero-filling -------------------------
rand_shocks <- function(sh_nat) {
  # Keep country-level info (e.g., IncomeGroup)
  static_cols <- sh_nat %>%
    distinct(ISO3, IncomeGroup)
  
  # Create full grid of years × shocks × countries
  grid_all <- expand_grid(
    ISO3 = unique(sh_nat$ISO3),
    Year = unique(sh_nat$Year),
    Shock.type = unique(sh_nat$Shock.type),
    Shock.category = unique(sh_nat$Shock.category)
  )
  
  # Fill missing with zeros
  sh_full <- sh_nat %>%
    group_by(ISO3, Year, Shock.type, Shock.category) %>%
    summarise(count = sum(count, na.rm = TRUE), .groups = "drop") %>%
    right_join(grid_all, by = c("ISO3","Year","Shock.type","Shock.category")) %>%
    mutate(count = replace_na(count, 0)) %>%
    left_join(static_cols, by = "ISO3")  # ← restore IncomeGroup
  
  # Randomize counts within country × type × category
  sh_full %>%
    group_by(ISO3, Shock.type, Shock.category) %>%
    mutate(count = sample(count, length(count), replace = FALSE)) %>%
    ungroup()
}


# ---- 3. Regression by time window ----------------------------------
run_reg <- function(region, rtype, lag_label, s_off, e_off, risks_long, shocks_reg) {
  r_filt <- risks_long %>% filter(Risk_Type == rtype) %>% rename(Risk_Year = Year)
  s_filt <- shocks_reg %>% filter(Region == region, Shock_Type == rtype) %>% rename(Shock_Year = Year)
  
  merged <- r_filt %>%
    rowwise() %>%
    mutate(
      sh_start = Risk_Year + s_off,
      sh_end   = Risk_Year + e_off,
      avg_shock = {
        vals <- s_filt %>% filter(Shock_Year >= sh_start, Shock_Year <= sh_end) %>%
          pull(Shock_Occ)
        if (length(vals) == (e_off - s_off + 1)) mean(vals, na.rm = TRUE) else NA_real_
      }
    ) %>%
    ungroup() %>%
    filter(!is.na(avg_shock))
  
  if (nrow(merged) < 5) return(NULL)
  mod <- lm(avg_shock ~ Risk_Score, data = merged)
  tidy(mod) %>%
    mutate(Region = region, Risk_Type = rtype, Lag = lag_label, N = nrow(merged))
}


# ---- 4. One simulation iteration -----------------------------------
run_sim <- function(i, sh_nat, reg_key, risks_long, lag_win, map_risk) {
  message("Simulation ", i)
  sh_sim <- rand_shocks(sh_nat)
  
  sh_reg <- make_shocks_reg(
    sh_sim, reg_key,
    method = "category_first",
    reg_level = "income",
    cutoff = TRUE
  ) %>% mutate(Shock_Type = recode(Shock_Type, !!!map_risk))
  
  regs <- unique(sh_reg$Region)
  rtypes <- intersect(unique(risks_long$Risk_Type), unique(sh_reg$Shock_Type))
  
  purrr::pmap_dfr(
    expand_grid(Region = regs, Risk_Type = rtypes, lag_win),
    function(Region, Risk_Type, Lag_Label, Start_Offset, End_Offset) {
      run_reg(Region, Risk_Type, Lag_Label, Start_Offset, End_Offset, risks_long, sh_reg)
    }
  ) %>% filter(term == "Risk_Score") %>% mutate(Sim = i)
}

############# GLOBAL EXPANDING WINDOW FUNCTIONS

# ====================================================================
# --------- HELPERS (GLOBAL expanding-window regressions) ------------
# ====================================================================

# 1) Expanding-window regression at GLOBAL level (no Region)
#    - uses pre-smoothed, globally aggregated datasets by window size
run_reg_expand_glob <- function(rtype,
                                max_lag = 5,
                                risks_long,
                                smoothed_glob_sets,
                                include0 = TRUE,
                                min_n = 5) {
  r_filt <- risks_long %>%
    filter(Risk_Type == rtype) %>%
    rename(Risk_Year = Year)
  
  lags <- setdiff(seq(-max_lag, max_lag), 0)
  
  purrr::map_dfr(lags, function(l) {
    width <- abs(l)
    s_tmp <- smoothed_glob_sets[[paste0("lag", width)]] %>%
      filter(Shock_Type == rtype) %>%
      rename(Shock_Year = Year)
    
    merged <- r_filt %>%
      rowwise() %>%
      mutate(
        Avg_Shock = {
          offsets <- if (l < 0) (-width:-1) else (1:width)
          years <- Risk_Year + offsets
          if (include0) years <- c(Risk_Year, years)
          vals <- s_tmp %>% filter(Shock_Year %in% years) %>% pull(Shock_Occ)
          if (length(vals) == 0) NA_real_ else mean(vals, na.rm = TRUE)
        }
      ) %>%
      ungroup() %>%
      filter(!is.na(Avg_Shock))
    
    if (nrow(merged) < min_n) {
      return(tibble(
        term = "Risk_Score", estimate = NA_real_, std.error = NA_real_,
        statistic = NA_real_, p.value = NA_real_,
        Risk_Type = rtype, Lag = l, N = nrow(merged)
      ))
    }
    
    mod <- lm(Avg_Shock ~ Risk_Score, data = merged)
    broom::tidy(mod) %>% mutate(Risk_Type = rtype, Lag = l, N = nrow(merged))
  })
}

# 2) Worker for GLOBAL simulation at a set of lags (reads pre-randomized files)
#    - IMPORTANT FIX: filter returned Lag == l (no overwriting)

run_reg_expand_glob <- function(rtype,
                                max_lag = 5,
                                risks_long,
                                smoothed_glob_sets,
                                include0 = TRUE,
                                min_n = 5) {
  r_filt <- risks_long %>%
    filter(Risk_Type == rtype) %>%
    rename(Risk_Year = Year)
  
  lags <- setdiff(seq(-max_lag, max_lag), 0)
  
  purrr::map_dfr(lags, function(l) {
    width <- abs(l)
    lag_name <- paste0("lag", width)
    
    # 🔒 SAFEGUARD: skip if dataset missing or NULL
    if (!lag_name %in% names(smoothed_glob_sets) ||
        is.null(smoothed_glob_sets[[lag_name]])) {
      message("⚠️ Missing ", lag_name, " for risk ", rtype, " at lag ", l)
      return(tibble())
    }
    
    s_tmp <- smoothed_glob_sets[[lag_name]]
    if (!"Shock_Type" %in% names(s_tmp)) {
      message("⚠️ No Shock_Type column in ", lag_name)
      return(tibble())
    }
    
    s_tmp <- s_tmp %>%
      filter(Shock_Type == rtype) %>%
      rename(Shock_Year = Year)
    
    if (nrow(s_tmp) == 0) return(tibble())
    
    merged <- r_filt %>%
      rowwise() %>%
      mutate(
        Avg_Shock = {
          offsets <- if (l < 0) (-width:-1) else (1:width)
          years <- Risk_Year + offsets
          if (include0) years <- c(Risk_Year, years)
          vals <- s_tmp %>% filter(Shock_Year %in% years) %>% pull(Shock_Occ)
          if (length(vals) == 0) NA_real_ else mean(vals, na.rm = TRUE)
        }
      ) %>%
      ungroup() %>%
      filter(!is.na(Avg_Shock))
    
    if (nrow(merged) < min_n) {
      return(tibble(
        term = "Risk_Score", estimate = NA_real_,
        std.error = NA_real_, statistic = NA_real_,
        p.value = NA_real_, Risk_Type = rtype,
        Lag = l, N = nrow(merged)
      ))
    }
    
    mod <- lm(Avg_Shock ~ Risk_Score, data = merged)
    broom::tidy(mod) %>% mutate(Risk_Type = rtype, Lag = l, N = nrow(merged))
  })
}


