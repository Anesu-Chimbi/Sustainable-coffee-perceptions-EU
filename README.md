# Sustainable Coffee Perceptions in Europe 🌿☕

Geospatial and sentiment analysis of how European consumers discuss sustainable coffee on X (formerly Twitter), using the X API v2 and R.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Project Structure](#project-structure)
3. [Setup Instructions](#setup-instructions)
   - [Prerequisites](#prerequisites)
   - [Clone the Repository](#clone-the-repository)
   - [Install R Packages](#install-r-packages)
   - [Fix the X API Integration](#fix-the-x-api-integration)
4. [Running the Analysis](#running-the-analysis)
5. [Analysis Pipeline](#analysis-pipeline)
6. [Outputs](#outputs)
7. [Troubleshooting the X API](#troubleshooting-the-x-api)
8. [Data Notes](#data-notes)
9. [Contributing](#contributing)

---

## Project Overview

**Objective:** Understand how sustainability topics related to coffee are discussed across Europe, using geospatial analysis of social media data.

| Property | Detail |
|---|---|
| Data source | X (Twitter) API v2 |
| Query | `"sustainable coffee"`, `"fair trade coffee"`, `"eco coffee"` |
| Language | English |
| Geography | Europe (15–20 countries) |
| Sentiment engine | VADER + AFINN lexicon |
| Mapping library | `sf` + `rnaturalearth` + `ggplot2` |

---

## Project Structure

```
Sustainable-coffee-perceptions-europe/
│
├── Sustainable-coffee/
│   ├── data/
│   │   ├── raw/                    # Raw API response (git-ignored)
│   │   └── processed/              # Cleaned + enriched data (git-ignored)
│   │
│   ├── scripts/
│   │   ├── 01_data_collection.R    # X API auth + tweet collection
│   │   ├── 02_data_cleaning.R      # Text cleaning + feature engineering
│   │   ├── 03_sentiment_analysis.R # VADER + AFINN sentiment scoring
│   │   ├── 04_geospatial_analysis.R# Maps and regional analysis
│   │   └── run_all.R               # Master script (runs 01–04 in order)
│   │
│   └── outputs/                    # PNG maps + charts (git-ignored)
│
├── .env.example                    # Template for API credentials
├── .gitignore
└── README.md
```

---

## Setup Instructions

### Prerequisites

- **R** ≥ 4.2 ([download](https://cran.r-project.org/))
- **RStudio** (recommended, [download](https://posit.co/download/rstudio-desktop/))
- An **X Developer Account** with API v2 access

### Clone the Repository

```bash
git clone https://github.com/<your-username>/Sustainable-coffee-perceptions-europe.git
cd Sustainable-coffee-perceptions-europe
```

### Install R Packages

All required packages are installed automatically when you run the scripts. To install them manually upfront:

```r
install.packages(c(
  "httr2", "jsonlite", "dplyr", "readr", "lubridate", "dotenv", "here",
  "stringr", "tidyr", "tidytext", "textdata", "vader", "ggplot2",
  "sf", "rnaturalearth", "rnaturalearthdata", "viridis",
  "ggrepel", "patchwork", "scales", "forcats"
))
```

---

### Fix the X API Integration

This is the section that was previously blocking the project. Follow these steps carefully.

#### Step 1 — Create a Developer Account

1. Go to [developer.twitter.com](https://developer.twitter.com/)
2. Click **Sign up** and apply for access
3. Select **Free** tier (sufficient for this project's search needs)
4. Complete the use-case description (e.g. "Academic research on consumer sustainability perceptions")

#### Step 2 — Create a Project and App

1. In the Developer Portal, click **+ Create Project**
2. Name it (e.g. `sustainable-coffee-europe`)
3. Inside the project, click **+ Add App**
4. Choose **Development** environment

#### Step 3 — Get Your Bearer Token

> ⚠️ The Bearer Token is all you need. You do **not** need OAuth 1.0a keys for read-only search.

1. Go to your App → **Keys and Tokens**
2. Under **Authentication Tokens**, copy the **Bearer Token**
3. If it's not visible, click **Regenerate**

#### Step 4 — Save Your Token Securely

```bash
# In the project root, copy the template
cp .env.example .env
```

Open `.env` and replace the placeholder:

```
BEARER_TOKEN=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAbcdef...
```

> ✅ `.env` is already in `.gitignore` — it will never be committed.

#### Step 5 — Common API Errors and Fixes

| Error | Cause | Fix |
|---|---|---|
| `401 Unauthorized` | Invalid or expired token | Regenerate Bearer Token in the portal |
| `403 Forbidden` | Your app lacks the right permissions | Ensure your app has **Read** permissions enabled |
| `429 Too Many Requests` | Rate limit hit | Script already throttles to 1 req/15s; just wait |
| `400 Bad Request` | Malformed query string | Check the `QUERY` variable in `01_data_collection.R` |
| `453 Access to a subset of Twitter V2 API...` | Free tier restriction | Some operators (e.g. `has:geo`) need Basic tier ($100/mo); use mock data or country-filtering in post-processing |

#### API Tier Comparison

| Feature | Free | Basic ($100/mo) |
|---|---|---|
| Recent search (7 days) | ✅ 500k tweets/month | ✅ 10M tweets/month |
| `has:geo` operator | ❌ | ✅ |
| Full archive search | ❌ | ❌ (Pro only) |

> **Recommendation:** Start with the **Free tier**. The scripts handle geo-tagging via `place` fields when available and fall back to country-level analysis using tweet metadata.

---

## Running the Analysis

### Option A — Run All Scripts at Once

```r
# In R or RStudio, from the project root:
source("Sustainable-coffee/scripts/run_all.R")
```

### Option B — Run Scripts Individually

```r
source("Sustainable-coffee/scripts/01_data_collection.R")
source("Sustainable-coffee/scripts/02_data_cleaning.R")
source("Sustainable-coffee/scripts/03_sentiment_analysis.R")
source("Sustainable-coffee/scripts/04_geospatial_analysis.R")
```

### No API Token? Use Mock Data

If no Bearer Token is set, `01_data_collection.R` automatically generates a realistic mock dataset of 1,000 tweets with simulated European locations and varied text. **All downstream scripts work identically with mock data**, so you can develop and test the full pipeline without API access.

---

## Analysis Pipeline

```
01_data_collection.R
  └─ Authenticates with X API v2
  └─ Searches for sustainable coffee tweets in Europe
  └─ Saves: data/raw/tweets_raw.csv

02_data_cleaning.R
  └─ Removes URLs, mentions, non-ASCII characters
  └─ Parses timestamps, extracts hashtags
  └─ Tags tweets by sustainability theme
  └─ Saves: data/processed/tweets_clean.csv

03_sentiment_analysis.R
  └─ VADER scoring (tweet-optimised, handles slang + emojis)
  └─ AFINN word-level lexicon analysis
  └─ Sentiment by country and by theme
  └─ Saves: data/processed/tweets_with_sentiment.csv
  └─ Outputs: sentiment_overall.png, sentiment_by_country.png

04_geospatial_analysis.R
  └─ Choropleth maps (volume + sentiment)
  └─ Dot map of individual tweet locations
  └─ Bubble map (volume × sentiment)
  └─ Outputs: map_*.png, maps_combined.png
```

---

## Outputs

All outputs are saved to `Sustainable-coffee/outputs/`:

| File | Description |
|---|---|
| `sentiment_overall.png` | Donut chart of positive / neutral / negative split |
| `sentiment_by_country.png` | Horizontal bar chart, mean VADER score per country |
| `sentiment_top_words.png` | Top AFINN words by contribution |
| `map_tweet_volume.png` | Choropleth — tweet count by country |
| `map_sentiment_choro.png` | Choropleth — mean sentiment by country |
| `map_tweet_dots.png` | Dot map — individual tweet locations coloured by sentiment |
| `map_bubble.png` | Bubble map — volume and sentiment combined |
| `maps_combined.png` | 2×2 panel of all four maps |

---

## Data Notes

- **Geo-tagging rate:** Only ~1–3% of tweets include precise coordinates. Country-level analysis uses `place` metadata, which is more common.
- **Language:** Query filters for English (`lang:en`). Tweets from non-English-speaking countries (e.g. Germany, France) may be under-represented.
- **Time window:** Free tier search covers the last **7 days** only. Re-run regularly to build a longitudinal dataset.
- **Mock data:** The simulated dataset uses realistic country distributions based on known European social media usage patterns, and is suitable for developing and testing the pipeline.

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-analysis`
3. Commit your changes: `git commit -m "Add time-series sentiment chart"`
4. Push and open a Pull Request

---

*Last updated: May 2026*
