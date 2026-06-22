# --------------------------------------------------------------
# FIXED: run_lag_worker — keep Lag as returned; filter Lag == l
# --------------------------------------------------------------
run_lag_worker <- function(lag_set, sh_nat, rand_files, reg_key, risks_long, map_risk,
                           reg_level = "income", include0 = TRUE, min_n = 5) {
  library(dplyr); library(purrr); library(broom)
  results_all <- vector("list", length(lag_set))
  
  for (l in lag_set) {
    if (l == 0) {
      message("Skipping lag 0 (no regression window)")
      next
    }
    message("Processing lag ", l)
    window_size <- abs(l)
    
    # (real data pass not used further, but keeps Region/Risk universe aligned)
    sh_nat_smooth <- if (window_size == 0) sh_nat else smooth_nat_shocks(sh_nat, window = window_size)
    sh_reg_real <- make_shocks_reg(
      sh_nat_smooth, reg_key,
      method = "category_first",
      reg_level = reg_level,
      cutoff = TRUE
    ) %>%
      mutate(Shock_Type = dplyr::recode(Shock_Type, !!!map_risk))
    
    regs   <- unique(sh_reg_real$Region)
    rtypes <- intersect(unique(risks_long$Risk_Type), unique(sh_reg_real$Shock_Type))
    
    # Loop all randomisations
    lag_results <- purrr::map_dfr(rand_files, function(f) {
      sh_sim <- readRDS(f)
      sh_sim_smooth <- if (window_size == 0) sh_sim else smooth_nat_shocks(sh_sim, window = window_size)
      sh_reg_sim <- make_shocks_reg(
        sh_sim_smooth, reg_key,
        method = "category_first",
        reg_level = reg_level,
        cutoff = TRUE
      ) %>%
        mutate(Shock_Type = dplyr::recode(Shock_Type, !!!map_risk))
      
      res <- purrr::pmap_dfr(
        tidyr::expand_grid(Region = regs, Risk_Type = rtypes),
        function(Region, Risk_Type) {
          run_reg_expand_reg(
            region = Region,
            rtype  = Risk_Type,
            max_lag = abs(l),  # compute ± up to |l|
            risks_long = risks_long,
            # provide only the |l| dataset so run_reg_expand_reg can pull the right one
            smoothed_reg_sets = purrr::set_names(list(sh_reg_sim), paste0("lag", abs(l))),
            include0 = include0,
            min_n = min_n
          )
        }
      )
      
      # ---- FIX: do NOT overwrite Lag; keep only the requested direction
      if (!"term" %in% names(res)) {
        tibble()
      } else {
        res %>%
          dplyr::filter(term == "Risk_Score", Lag == l) %>%  # keep correct direction
          dplyr::mutate(Sim = basename(f))                   # append Sim only
      }
    })
    
    results_all[[as.character(l)]] <- lag_results
  }
  
  dplyr::bind_rows(results_all)
}
