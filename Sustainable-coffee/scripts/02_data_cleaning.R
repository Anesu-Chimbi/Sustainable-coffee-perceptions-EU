# =============================================================================
# 02_data_cleaning.R
# Sustainable Coffee Perceptions in Europe
# Description: Clean raw tweet data and prepare for analysis
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(lubridate)
  library(tidyr)
  library(here)
})

cat("=== Data Cleaning Pipeline ===\n")

# ── 1. Load Raw Data ───────────────────────────────────────────────────────────
raw_path <- here("Sustainable-coffee/data/raw/tweets_raw.csv")
if (!file.exists(raw_path)) stop("❌ Raw data not found. Run 01_data_collection.R first.")

tweets_raw <- read_csv(raw_path, show_col_types = FALSE)
cat(sprintf("📥 Loaded %d raw tweets\n", nrow(tweets_raw)))

# ── 2. Text Cleaning Functions ─────────────────────────────────────────────────
clean_text <- function(text) {
  text |>
    str_remove_all("https?://\\S+") |>       # URLs
    str_remove_all("@\\w+") |>               # @mentions
    str_remove_all("[^\x20-\x7E]") |>        # non-ASCII (emojis etc.)
    str_squish() |>
    str_trim()
}

extract_hashtags <- function(text) {
  matches <- str_extract_all(text, "#\\w+")
  sapply(matches, function(x) if (length(x) == 0) NA_character_ else paste(tolower(x), collapse = " | "))
}

# ── 3. Clean & Enrich ──────────────────────────────────────────────────────────
tweets_clean <- tweets_raw |>
  mutate(
    created_at  = as.POSIXct(
                    sub("Z$", "", created_at),
                    format = "%Y-%m-%dT%H:%M:%S", tz = "UTC"
                  ),
    date        = as_date(created_at),
    month       = floor_date(created_at, "month"),
    hour        = hour(created_at),
    day_of_week = wday(created_at, label = TRUE, abbr = FALSE),
    hashtags    = extract_hashtags(text),
    text_clean  = clean_text(text),
    word_count  = str_count(text_clean, "\\S+"),
    char_count  = nchar(text_clean),
    has_geo     = !is.na(latitude) & !is.na(longitude)
  ) |>
  filter(!is.na(text_clean), word_count >= 3) |>
  distinct(tweet_id, .keep_all = TRUE) |>
  select(
    tweet_id, date, month, day_of_week, hour,
    text, text_clean, hashtags, word_count, char_count,
    country, country_code, latitude, longitude, has_geo,
    any_of("is_mock")
  )

cat(sprintf("✅ Cleaned: %d tweets retained (%.1f%%)\n",
    nrow(tweets_clean), 100 * nrow(tweets_clean) / nrow(tweets_raw)))
cat(sprintf("📍 Geo-tagged: %d (%.1f%%)\n",
    sum(tweets_clean$has_geo), 100 * mean(tweets_clean$has_geo)))

# ── 4. Theme Tagging ───────────────────────────────────────────────────────────
tag_theme <- function(text) {
  text_low <- tolower(text)
  themes <- c(
    certification  = "certif|fair.?trade|rainforest|organic|utz|4c",
    packaging      = "packag|compostab|recyclable|plastic|cup|biodeg",
    supply_chain   = "supply.?chain|origin|sourc|farmer|farm|ethiopia|colombia|brazil",
    carbon         = "carbon|co2|emission|climate|footprint|neutral",
    greenwashing   = "greenwash|mislead|fake|label|trust",
    consumer       = "buy|purchas|afford|price|expensiv|cheap|premium",
    corporate      = "brand|company|cafe|roaster|chain|starbucks|nespresso"
  )
  matched <- names(themes)[str_detect(text_low, themes)]
  if (length(matched) == 0) "general" else paste(matched, collapse = " | ")
}

tweets_clean <- tweets_clean |>
  mutate(theme = sapply(text, tag_theme))

cat("\n📊 Theme distribution:\n")
tweets_clean |>
  separate_rows(theme, sep = " \\| ") |>
  count(theme, sort = TRUE) |>
  mutate(pct = sprintf("%.1f%%", 100 * n / nrow(tweets_clean))) |>
  print()

# ── 5. Country Summary ─────────────────────────────────────────────────────────
country_summary <- tweets_clean |>
  filter(!is.na(country)) |>
  count(country, country_code, name = "n_tweets") |>
  arrange(desc(n_tweets)) |>
  mutate(pct = round(100 * n_tweets / sum(n_tweets), 1))

cat("\n🌍 Top 10 countries:\n")
print(head(country_summary, 10))

# ── 6. Save ───────────────────────────────────────────────────────────────────
proc_dir <- here("Sustainable-coffee/data/processed")
dir.create(proc_dir, showWarnings = FALSE, recursive = TRUE)

write_csv(tweets_clean,    file.path(proc_dir, "tweets_clean.csv"))
write_csv(country_summary, file.path(proc_dir, "country_summary.csv"))
cat(sprintf("\n💾 Saved cleaned data → %s\n", proc_dir))
