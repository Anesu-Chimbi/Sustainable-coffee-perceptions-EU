# =============================================================================
# run_all.R
# Sustainable Coffee Perceptions in Europe
# Description: Master script — runs the full analysis pipeline in order
# =============================================================================

cat("╔══════════════════════════════════════════════════════════╗\n")
cat("║  Sustainable Coffee Perceptions — Full Analysis Pipeline ║\n")
cat("╚══════════════════════════════════════════════════════════╝\n\n")

scripts <- c(
  "Sustainable-coffee/scripts/01_data_collection.R",
  "Sustainable-coffee/scripts/02_data_cleaning.R",
  "Sustainable-coffee/scripts/03_sentiment_analysis.R",
  "Sustainable-coffee/scripts/04_geospatial_analysis.R"
)

for (script in scripts) {
  cat(sprintf("\n▶ Running: %s\n", script))
  cat(strrep("─", 60), "\n")
  tryCatch(
    source(here::here(script), echo = FALSE),
    error = function(e) {
      cat(sprintf("❌ ERROR in %s:\n   %s\n", script, conditionMessage(e)))
      stop("Pipeline halted.")
    }
  )
  cat(sprintf("✅ Completed: %s\n", script))
}

cat("\n╔══════════════════════════════════════════════════════════╗\n")
cat("║              🎉 Pipeline Complete!                       ║\n")
cat("╚══════════════════════════════════════════════════════════╝\n")
cat("\nOutputs are in: Sustainable-coffee/outputs/\n")
cat("Processed data: Sustainable-coffee/data/processed/\n")
