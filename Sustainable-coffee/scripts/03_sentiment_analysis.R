# =============================================================================
# 03_sentiment_analysis.R
# Sustainable Coffee Perceptions in Europe
# Description: Sentiment analysis using the Bing lexicon (built into tidytext)
#              and a simple compound score — no external downloads required.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidytext)
  library(stringr)
  library(ggplot2)
  library(forcats)
  library(tidyr)
  library(here)
  library(scales)
})

cat("=== Sentiment Analysis ===\n")

# ── 1. Load Data ───────────────────────────────────────────────────────────────
clean_path <- here("Sustainable-coffee/data/processed/tweets_clean.csv")
if (!file.exists(clean_path)) stop("❌ Run 02_data_cleaning.R first.")

tweets <- read_csv(clean_path, show_col_types = FALSE)
cat(sprintf("📥 Loaded %d tweets\n", nrow(tweets)))

# ── 2. Bing Lexicon (bundled with tidytext — no download needed) ───────────────
bing <- get_sentiments("bing")
cat(sprintf("📖 Bing lexicon: %d words\n", nrow(bing)))

# ── 3. Word-level Sentiment Scoring ───────────────────────────────────────────
# Tokenise, remove stop words, join Bing scores
word_scores <- tweets |>
  select(tweet_id, text_clean) |>
  unnest_tokens(word, text_clean) |>
  anti_join(stop_words, by = "word") |>
  inner_join(bing, by = "word") |>
  mutate(score = if_else(sentiment == "positive", 1L, -1L))

# Per-tweet aggregate: sum of word scores
tweet_scores <- word_scores |>
  group_by(tweet_id) |>
  summarise(
    n_sentiment_words = n(),
    raw_score         = sum(score),
    pos_words         = sum(score > 0),
    neg_words         = sum(score < 0),
    .groups           = "drop"
  ) |>
  mutate(
    # Normalise to [-1, 1] like VADER compound
    compound = raw_score / pmax(n_sentiment_words, 1),
    compound = pmax(pmin(compound, 1), -1),
    sentiment_label = case_when(
      compound >  0.05 ~ "Positive",
      compound < -0.05 ~ "Negative",
      TRUE             ~ "Neutral"
    )
  )

# Tweets with no matched Bing words → Neutral
tweets_sentiment <- tweets |>
  left_join(tweet_scores, by = "tweet_id") |>
  mutate(
    compound        = replace_na(compound, 0),
    raw_score       = replace_na(raw_score, 0L),
    sentiment_label = replace_na(sentiment_label, "Neutral")
  )

cat("\n📊 Overall sentiment:\n")
tweets_sentiment |>
  count(sentiment_label) |>
  mutate(pct = sprintf("%.1f%%", 100 * n / sum(n))) |>
  print()

# ── 4. Top Sentiment Words ─────────────────────────────────────────────────────
top_words <- word_scores |>
  group_by(word, sentiment) |>
  summarise(n = n(), .groups = "drop") |>
  arrange(desc(n)) |>
  group_by(sentiment) |>
  slice_head(n = 15) |>
  ungroup()

cat("\n📝 Top positive words:\n")
top_words |> filter(sentiment == "positive") |> print()
cat("\n📝 Top negative words:\n")
top_words |> filter(sentiment == "negative") |> print()

# ── 5. Sentiment by Country ────────────────────────────────────────────────────
country_sentiment <- tweets_sentiment |>
  filter(!is.na(country)) |>
  group_by(country, country_code) |>
  summarise(
    n_tweets     = n(),
    mean_compound = round(mean(compound, na.rm = TRUE), 3),
    pct_positive  = round(100 * mean(sentiment_label == "Positive"), 1),
    pct_negative  = round(100 * mean(sentiment_label == "Negative"), 1),
    pct_neutral   = round(100 * mean(sentiment_label == "Neutral"),  1),
    .groups = "drop"
  ) |>
  filter(n_tweets >= 10) |>
  arrange(desc(mean_compound))

cat("\n🌍 Sentiment by country:\n")
print(country_sentiment)

# ── 6. Sentiment by Theme ──────────────────────────────────────────────────────
theme_sentiment <- tweets_sentiment |>
  separate_rows(theme, sep = " \\| ") |>
  group_by(theme) |>
  summarise(
    n          = n(),
    mean_score = round(mean(compound, na.rm = TRUE), 3),
    pct_pos    = round(100 * mean(sentiment_label == "Positive"), 1),
    pct_neg    = round(100 * mean(sentiment_label == "Negative"), 1),
    .groups    = "drop"
  ) |>
  arrange(desc(mean_score))

cat("\n📌 Sentiment by theme:\n")
print(theme_sentiment)

# ── 7. Plots ───────────────────────────────────────────────────────────────────
out_dir <- here("Sustainable-coffee/outputs")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# 7a — Overall donut
p1 <- tweets_sentiment |>
  count(sentiment_label) |>
  mutate(
    pct   = n / sum(n),
    label = sprintf("%s\n%.1f%%", sentiment_label, pct * 100)
  ) |>
  ggplot(aes(x = 2, y = pct, fill = sentiment_label)) +
  geom_col(width = 1, colour = "white", linewidth = 0.6) +
  geom_text(aes(label = label),
            position = position_stack(vjust = 0.5),
            size = 4, fontface = "bold") +
  coord_polar(theta = "y") +
  xlim(0.5, 2.5) +
  scale_fill_manual(values = c(Positive = "#27ae60",
                                Neutral  = "#95a5a6",
                                Negative = "#e74c3c")) +
  labs(title    = "Overall Sentiment — Sustainable Coffee Tweets",
       subtitle = sprintf("n = %d tweets | Bing lexicon", nrow(tweets_sentiment))) +
  theme_void(base_size = 12) +
  theme(legend.position  = "none",
        plot.title       = element_text(hjust = 0.5, face = "bold"),
        plot.subtitle    = element_text(hjust = 0.5, colour = "grey50"))

ggsave(file.path(out_dir, "sentiment_overall.png"), p1,
       width = 6, height = 5, dpi = 150, bg = "white")

# 7b — By country
p2 <- country_sentiment |>
  filter(n_tweets >= 20) |>
  mutate(country = fct_reorder(country, mean_compound)) |>
  ggplot(aes(x = mean_compound, y = country, fill = mean_compound)) +
  geom_col() +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey30") +
  scale_fill_gradient2(low = "#e74c3c", mid = "#ecf0f1",
                       high = "#27ae60", midpoint = 0) +
  labs(title    = "Mean Sentiment Score by Country",
       subtitle = "Sustainable coffee discussions on X",
       x = "Mean Compound Score", y = NULL) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"), legend.position = "none")

ggsave(file.path(out_dir, "sentiment_by_country.png"), p2,
       width = 7, height = 6, dpi = 150, bg = "white")

# 7c — Top words
p3 <- top_words |>
  mutate(
    n2   = if_else(sentiment == "negative", -n, n),
    word = fct_reorder(word, n2)
  ) |>
  ggplot(aes(x = n2, y = word, fill = sentiment)) +
  geom_col() +
  geom_vline(xintercept = 0, colour = "grey30") +
  scale_fill_manual(values = c(positive = "#27ae60", negative = "#c0392b")) +
  scale_x_continuous(labels = abs) +
  labs(title    = "Top Sentiment Words (Bing Lexicon)",
       subtitle = "Frequency across all tweets",
       x = "Word count", y = NULL, fill = NULL) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"), legend.position = "bottom")

ggsave(file.path(out_dir, "sentiment_top_words.png"), p3,
       width = 7, height = 7, dpi = 150, bg = "white")

# 7d — Sentiment by theme
p4 <- theme_sentiment |>
  mutate(theme = fct_reorder(theme, mean_score)) |>
  ggplot(aes(x = mean_score, y = theme, fill = mean_score)) +
  geom_col() +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey30") +
  scale_fill_gradient2(low = "#e74c3c", mid = "#ecf0f1",
                       high = "#27ae60", midpoint = 0) +
  labs(title    = "Mean Sentiment by Sustainability Theme",
       x = "Mean Compound Score", y = NULL) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"), legend.position = "none")

ggsave(file.path(out_dir, "sentiment_by_theme.png"), p4,
       width = 7, height = 5, dpi = 150, bg = "white")

cat(sprintf("\n📊 4 plots saved → %s\n", out_dir))

# ── 8. Save Data ───────────────────────────────────────────────────────────────
proc_dir <- here("Sustainable-coffee/data/processed")
write_csv(tweets_sentiment,  file.path(proc_dir, "tweets_with_sentiment.csv"))
write_csv(country_sentiment, file.path(proc_dir, "country_sentiment.csv"))
write_csv(theme_sentiment,   file.path(proc_dir, "theme_sentiment.csv"))
cat("💾 Sentiment data saved.\n")
