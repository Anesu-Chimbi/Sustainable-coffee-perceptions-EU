# =============================================================================
# 04_geospatial_analysis.R
# Sustainable Coffee Perceptions in Europe
# Description: Map tweet locations and sentiment across Europe.
#              Uses rnaturalearthdata directly (no rnaturalearth wrapper needed).
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
  library(sf)
  library(rnaturalearthdata)
  library(here)
  library(scales)
  library(viridis)
  library(ggrepel)
  library(patchwork)
  library(tidyr)
})

cat("=== Geospatial Analysis ===\n")

# ── 1. Load Data ───────────────────────────────────────────────────────────────
sentiment_path <- here("Sustainable-coffee/data/processed/tweets_with_sentiment.csv")
country_path   <- here("Sustainable-coffee/data/processed/country_sentiment.csv")
if (!file.exists(sentiment_path)) stop("❌ Run 03_sentiment_analysis.R first.")

tweets     <- read_csv(sentiment_path, show_col_types = FALSE)
country_df <- read_csv(country_path,   show_col_types = FALSE)
geo_tweets <- tweets |> filter(has_geo == TRUE, !is.na(latitude), !is.na(longitude))
cat(sprintf("📍 Geo-tagged tweets available: %d\n", nrow(geo_tweets)))

# ── 2. Build Europe Base Map from rnaturalearthdata ───────────────────────────
# countries50 is an sf-compatible SpatialPolygonsDataFrame in rnaturalearthdata
europe_sf <- sf::st_as_sf(rnaturalearthdata::countries50) |>
  filter(continent == "Europe") |>
  select(iso_a2, name, geometry)

# Crop to visible Europe (excludes far-east Russia)
europe_bbox <- st_bbox(c(xmin = -25, xmax = 45, ymin = 34, ymax = 72),
                       crs = st_crs(4326))
europe_sf <- suppressWarnings(st_crop(europe_sf, europe_bbox))

cat(sprintf("🗺️  Europe map: %d countries loaded\n", nrow(europe_sf)))

# ── 3. Join Country Sentiment ──────────────────────────────────────────────────
europe_joined <- europe_sf |>
  left_join(
    country_df |> select(country_code, n_tweets, mean_compound,
                          pct_positive, pct_negative),
    by = c("iso_a2" = "country_code")
  )

# ── 4. Shared theme ───────────────────────────────────────────────────────────
map_theme <- theme_void(base_size = 11) +
  theme(
    plot.title    = element_text(face = "bold", hjust = 0.5, size = 12),
    plot.subtitle = element_text(hjust = 0.5, colour = "grey50", size = 9),
    legend.position = "right"
  )

coord_europe <- coord_sf(xlim = c(-25, 45), ylim = c(34, 72), expand = FALSE)

# ── 5. Map 1 — Tweet Volume Choropleth ────────────────────────────────────────
p1 <- ggplot(europe_joined) +
  geom_sf(aes(fill = n_tweets), colour = "white", linewidth = 0.25) +
  scale_fill_viridis_c(
    option   = "plasma", na.value = "grey90",
    name     = "Tweets", labels = comma,
    guide    = guide_colourbar(barwidth = 0.7, barheight = 8)
  ) +
  coord_europe +
  labs(title    = "Tweet Volume by Country",
       subtitle = "Sustainable coffee discussions on X") +
  map_theme

# ── 6. Map 2 — Sentiment Choropleth ───────────────────────────────────────────
p2 <- ggplot(europe_joined) +
  geom_sf(aes(fill = mean_compound), colour = "white", linewidth = 0.25) +
  scale_fill_gradient2(
    low = "#c0392b", mid = "#f5f5f5", high = "#27ae60",
    midpoint = 0, na.value = "grey90", name = "Sentiment",
    guide = guide_colourbar(barwidth = 0.7, barheight = 8)
  ) +
  coord_europe +
  labs(title    = "Mean Sentiment by Country",
       subtitle = "Bing compound score (neg → pos)") +
  map_theme

# ── 7. Map 3 — Individual Tweet Dot Map ───────────────────────────────────────
geo_sf <- geo_tweets |>
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

p3 <- ggplot() +
  geom_sf(data = europe_sf, fill = "grey92", colour = "white", linewidth = 0.25) +
  geom_sf(data = geo_sf,
          aes(colour = sentiment_label),
          size = 1.4, alpha = 0.55, shape = 16) +
  scale_colour_manual(
    values = c(Positive = "#27ae60", Neutral = "#7f8c8d", Negative = "#c0392b"),
    name   = "Sentiment"
  ) +
  coord_europe +
  labs(title    = "Individual Tweet Locations",
       subtitle = "Colour = Bing sentiment label") +
  map_theme +
  theme(legend.position = "bottom",
        legend.direction = "horizontal")

# ── 8. Map 4 — Bubble Map: Volume × Sentiment ─────────────────────────────────
centroids <- europe_joined |>
  filter(!is.na(n_tweets)) |>
  st_centroid() |>
  mutate(
    lon = st_coordinates(geometry)[, 1],
    lat = st_coordinates(geometry)[, 2]
  ) |>
  st_drop_geometry()

p4 <- ggplot() +
  geom_sf(data = europe_sf, fill = "grey95", colour = "white", linewidth = 0.25) +
  geom_point(
    data  = centroids,
    aes(x = lon, y = lat, size = n_tweets, colour = mean_compound),
    alpha = 0.85
  ) +
  geom_text_repel(
    data      = centroids |> filter(n_tweets > 30),
    aes(x = lon, y = lat, label = name),
    size      = 2.6, colour = "grey20", max.overlaps = 10
  ) +
  scale_size_continuous(range = c(3, 16), name = "Volume") +
  scale_colour_gradient2(
    low = "#c0392b", mid = "#f5f5f5", high = "#27ae60",
    midpoint = 0, name = "Sentiment"
  ) +
  coord_europe +
  labs(title    = "Volume & Sentiment by Country",
       subtitle = "Size = tweet count · Colour = mean sentiment") +
  map_theme

# ── 9. Save Individual Maps ────────────────────────────────────────────────────
out_dir <- here("Sustainable-coffee/outputs")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

ggsave(file.path(out_dir, "map_tweet_volume.png"),    p1, width = 8, height = 7, dpi = 150, bg = "white")
ggsave(file.path(out_dir, "map_sentiment_choro.png"), p2, width = 8, height = 7, dpi = 150, bg = "white")
ggsave(file.path(out_dir, "map_tweet_dots.png"),      p3, width = 8, height = 7, dpi = 150, bg = "white")
ggsave(file.path(out_dir, "map_bubble.png"),          p4, width = 8, height = 7, dpi = 150, bg = "white")

# ── 10. Combined 2×2 Panel ────────────────────────────────────────────────────
combined <- (p1 | p2) / (p3 | p4) +
  plot_annotation(
    title   = "Sustainable Coffee on X — European Geospatial Analysis",
    caption = "Data: X API v2 (mock) | Lexicon: Bing (tidytext) | Maps: rnaturalearth",
    theme   = theme(
      plot.title   = element_text(face = "bold", hjust = 0.5, size = 15),
      plot.caption = element_text(colour = "grey55", size = 8)
    )
  )

ggsave(file.path(out_dir, "maps_combined.png"), combined,
       width = 16, height = 14, dpi = 150, bg = "white")

cat(sprintf("🗺️  All 5 map files saved → %s\n", out_dir))

# ── 11. Regional Summary Table ────────────────────────────────────────────────
regional_summary <- tweets |>
  filter(!is.na(country)) |>
  group_by(country, country_code) |>
  summarise(
    n_tweets   = n(),
    pct_geo    = round(100 * mean(has_geo, na.rm = TRUE), 1),
    mean_score = round(mean(compound, na.rm = TRUE), 3),
    pct_pos    = round(100 * mean(sentiment_label == "Positive"), 1),
    pct_neg    = round(100 * mean(sentiment_label == "Negative"), 1),
    top_theme  = {
      th <- sort(table(unlist(strsplit(theme, " \\| "))), decreasing = TRUE)
      names(th)[1]
    },
    .groups = "drop"
  ) |>
  arrange(desc(n_tweets))

write_csv(regional_summary,
          here("Sustainable-coffee/data/processed/regional_summary.csv"))
cat("💾 Regional summary saved.\n\n")
print(regional_summary)
