# =============================================================================
# 01_data_collection.R
# Sustainable Coffee Perceptions in Europe
# Description: Authenticate with X (Twitter) API v2 and collect tweets
# =============================================================================

# ── 1. Install & Load Dependencies ────────────────────────────────────────────
packages <- c("httr2", "jsonlite", "dplyr", "readr", "lubridate", "dotenv")

installed <- rownames(installed.packages())
to_install <- packages[!packages %in% installed]
if (length(to_install) > 0) install.packages(to_install, repos = "https://cran.rstudio.com/")

library(httr2)
library(jsonlite)
library(dplyr)
library(readr)
library(lubridate)
# dotenv not available; see header comment for manual token loading

# ── 2. Load API Credentials from .env ─────────────────────────────────────────
# Create a .env file in the project root with:
#   BEARER_TOKEN=your_bearer_token_here
#
# How to get a Bearer Token:
#   1. Go to https://developer.twitter.com/en/portal/dashboard
#   2. Create or select a Project + App
#   3. Navigate to "Keys and Tokens"
#   4. Copy the "Bearer Token" (used for read-only search — no OAuth needed)
#
# ⚠️  IMPORTANT: Never commit your .env file to Git!
#     It is already listed in .gitignore.

env_path <- here::here(".env")

if (file.exists(env_path)) {
  dotenv::load_dot_env(env_path)
  BEARER_TOKEN <- Sys.getenv("BEARER_TOKEN")
  cat("✅ Bearer Token loaded from .env\n")
} else {
  warning("⚠️  No .env file found. Set BEARER_TOKEN manually or create a .env file.")
  BEARER_TOKEN <- ""  # Will trigger mock data path below
}

# ── 3. X API v2 Search Configuration ──────────────────────────────────────────
# Twitter API v2 recent search endpoint (last 7 days, free tier)
# For full archive (Academic/Pro tier): use /2/tweets/search/all

BASE_URL    <- "https://api.twitter.com/2/tweets/search/recent"
QUERY       <- "(\"sustainable coffee\" OR \"eco coffee\" OR \"fair trade coffee\") lang:en"
MAX_RESULTS <- 100   # per request; max 100 on basic, max 500 on Pro
TARGET_N    <- 1000  # total tweets to collect (pagination)

# European bounding box for geo-filtering (used in post-processing)
# Note: API v2 free tier does not support geo operators reliably;
#       we filter by country in the cleaning script using place fields.
EUROPEAN_COUNTRIES <- c(
  "GB", "DE", "FR", "IT", "ES", "NL", "SE", "NO", "DK", "FI",
  "PL", "PT", "BE", "AT", "CH", "IE", "GR", "CZ", "HU", "RO"
)

# ── 4. Fetch Tweets Function ───────────────────────────────────────────────────
fetch_tweets <- function(bearer_token, query, max_results = 100, n_pages = 10) {

  if (bearer_token == "") {
    message("⚠️  No bearer token — returning mock dataset. See README to set up API access.")
    return(generate_mock_tweets(n = 1000))
  }

  all_tweets  <- list()
  next_token  <- NULL
  page        <- 1

  repeat {
    cat(sprintf("  Fetching page %d...\n", page))

    req <- request(BASE_URL) |>
      req_auth_bearer_token(bearer_token) |>
      req_url_query(
        query        = query,
        max_results  = max_results,
        `tweet.fields` = "created_at,text,geo,lang,public_metrics,author_id",
        `place.fields` = "country,country_code,full_name,geo",
        expansions   = "geo.place_id",
        next_token   = next_token
      ) |>
      req_retry(max_tries = 3, backoff = ~ 15) |>  # Respect rate limits
      req_throttle(rate = 1 / 15)                   # 1 request / 15 sec (free tier)

    resp <- tryCatch(
      req_perform(req),
      error = function(e) {
        message("❌ API error: ", conditionMessage(e))
        return(NULL)
      }
    )

    if (is.null(resp)) break

    body <- resp_body_json(resp, simplifyVector = TRUE)

    if (!is.null(body$data)) {
      all_tweets[[page]] <- body$data
    }

    next_token <- body$meta$next_token
    if (is.null(next_token) || page >= n_pages) break

    page <- page + 1
    Sys.sleep(15)  # Free tier: 1 request per 15 seconds
  }

  if (length(all_tweets) == 0) {
    message("⚠️  No tweets retrieved — falling back to mock dataset.")
    return(generate_mock_tweets(n = 1000))
  }

  bind_rows(all_tweets)
}

# ── 5. Mock Data Generator (Development / Fallback) ───────────────────────────
generate_mock_tweets <- function(n = 1000, seed = 42) {
  set.seed(seed)

  countries <- c(
    "United Kingdom", "Germany", "France", "Italy", "Spain",
    "Netherlands", "Sweden", "Denmark", "Norway", "Finland",
    "Poland", "Portugal", "Belgium", "Austria", "Ireland"
  )

  country_codes <- c(
    "GB", "DE", "FR", "IT", "ES",
    "NL", "SE", "DK", "NO", "FI",
    "PL", "PT", "BE", "AT", "IE"
  )

  country_coords <- list(
    GB = c(51.5, -0.1),  DE = c(52.5, 13.4),  FR = c(48.9, 2.3),
    IT = c(41.9, 12.5),  ES = c(40.4, -3.7),  NL = c(52.4, 4.9),
    SE = c(59.3, 18.1),  DK = c(55.7, 12.6),  NO = c(59.9, 10.8),
    FI = c(60.2, 25.0),  PL = c(52.2, 21.0),  PT = c(38.7, -9.1),
    BE = c(50.8, 4.4),   AT = c(48.2, 16.4),  IE = c(53.3, -6.2)
  )

  texts <- c(
    "Just tried a new #sustainable coffee brand — the packaging is compostable! ☕🌿",
    "Really impressed with how many European cafes are switching to #fairtrade coffee",
    "Not sure if 'eco coffee' labels actually mean anything anymore... #greenwashing?",
    "My local roaster sources direct-trade beans from Ethiopia. Great taste AND ethics 👌",
    "Sustainable coffee is trendy but is it actually accessible for everyone? Prices are high",
    "New study: consumers in Germany most likely to pay premium for certified #sustainablecoffee",
    "Love that @coffeeshop switched to biodegradable cups! Small steps matter ♻️☕",
    "Does your office serve fair trade coffee? Mine doesn't and it bothers me every morning",
    "Rainforest Alliance vs Fair Trade — which certification do you trust more? #coffee",
    "Carbon neutral coffee — is this actually achievable? Interesting article on supply chains",
    "Swedish coffee culture + sustainability = a natural fit 🇸🇪 #fika #sustainablecoffee",
    "The CO2 footprint of my morning espresso is something I try not to think about too much",
    "Organic, fair trade, shade-grown — how many certifications does one cup need? 😂",
    "Bought a kilo of sustainably sourced Ethiopian blend. Tastes amazing AND guilt-free!",
    "European coffee consumption is booming but sustainability in the supply chain needs work"
  )

  country_sample <- sample(seq_along(countries), n, replace = TRUE,
                           prob = c(.18,.14,.12,.10,.09,.07,.05,.04,.04,.03,.03,.03,.03,.02,.03))

  country_names <- countries[country_sample]
  country_code_vec <- country_codes[country_sample]

  lats <- sapply(country_code_vec, function(cc) {
    base <- country_coords[[cc]][1]
    base + rnorm(1, 0, 0.8)
  })
  lngs <- sapply(country_code_vec, function(cc) {
    base <- country_coords[[cc]][2]
    base + rnorm(1, 0, 1.2)
  })

  tibble(
    tweet_id     = paste0("mock_", seq_len(n)),
    text         = sample(texts, n, replace = TRUE),
    created_at   = as.character(
      as.POSIXct("2024-01-01") + runif(n, 0, 365 * 24 * 3600)
    ),
    country      = country_names,
    country_code = country_code_vec,
    latitude     = lats,
    longitude    = lngs,
    is_mock      = TRUE
  )
}

# ── 6. Run Collection ──────────────────────────────────────────────────────────
cat("=== Sustainable Coffee Tweet Collection ===\n")
cat(sprintf("Query  : %s\n", QUERY))
cat(sprintf("Target : %d tweets\n\n", TARGET_N))

tweets_raw <- fetch_tweets(
  bearer_token = BEARER_TOKEN,
  query        = QUERY,
  max_results  = MAX_RESULTS,
  n_pages      = ceiling(TARGET_N / MAX_RESULTS)
)

cat(sprintf("\n✅ Collected %d tweets\n", nrow(tweets_raw)))

# ── 7. Save Raw Data ───────────────────────────────────────────────────────────
output_path <- here::here("Sustainable-coffee/data/raw/tweets_raw.csv")
write_csv(tweets_raw, output_path)
cat(sprintf("💾 Saved raw data → %s\n", output_path))
