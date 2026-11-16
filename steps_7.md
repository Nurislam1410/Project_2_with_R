# Breakfast & Coffee in New Orleans — Step 7: All Reviewers vs Selected Reviewers


- [All reviewers](#all-reviewers)
- [Select reviewers with enough
  activity](#select-reviewers-with-enough-activity)
- [Normalize each reviewer’s scores](#normalize-each-reviewers-scores)
- [Compare raw and reviewer-adjusted
  results](#compare-raw-and-reviewer-adjusted-results)
  - [Top 10 by raw average (all
    reviewers)](#top-10-by-raw-average-all-reviewers)
  - [Top 10 by reviewer-adjusted score (eligible reviewers, median
    baseline)](#top-10-by-reviewer-adjusted-score-eligible-reviewers-median-baseline)
  - [Largest rank changes after
    normalization](#largest-rank-changes-after-normalization)
- [Neighborhoods: raw vs
  reviewer-adjusted](#neighborhoods-raw-vs-reviewer-adjusted)
- [Final map: top 10](#final-map-top-10)

Step 7 compares ordinary Yelp averages (all reviewers) with
reviewer-adjusted scores from reviewers who wrote enough reviews in the
selected categories for a personal baseline to mean something. The
selected restaurants, the reviews and the Neighborhood Statistical Areas
(NSAs) are rebuilt here exactly as in
[`steps_3_to_6.qmd`](steps_3_to_6.qmd).

``` r
library(tidyverse)
library(lubridate)
library(sf)
library(tigris)
options(tigris_use_cache = TRUE)
sf_use_s2(FALSE)

restaurants <- readRDS("data/new_orleans/business_new_orleans.rds")
reviews     <- readRDS("data/new_orleans/reviews_new_orleans.rds")

selected_categories <- c("breakfast & brunch", "coffee & tea", "cafes", "bakeries")

selected_ids <- restaurants |>
  select(business_id, categories) |>
  separate_rows(categories, sep = ",") |>
  mutate(category = str_to_lower(str_squish(categories))) |>
  filter(category %in% selected_categories) |>
  distinct(business_id)

selected_restaurants <- restaurants |>
  semi_join(selected_ids, by = "business_id")

# Neighborhood (NSA) for each restaurant, as chosen in Step 6
nsa <- st_read("data/boundaries/nsa.geojson", quiet = TRUE) |>
  transmute(area_name = gnocdc_lab)

restaurant_area <- selected_restaurants |>
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE) |>
  st_transform(st_crs(nsa)) |>
  st_join(nsa, join = st_within, left = TRUE) |>
  st_drop_geometry() |>
  select(business_id, area_name)

category_reviews <- reviews |>
  semi_join(selected_restaurants, by = "business_id") |>
  mutate(review_date = ymd_hms(date, quiet = TRUE),
         review_year = year(review_date))
```

## All reviewers

``` r
all_reviewer_summary <- category_reviews |>
  group_by(business_id) |>
  summarise(
    number_of_reviews_all_reviewers = n(),
    average_stars_all_reviewers     = mean(stars, na.rm = TRUE),
    median_stars_all_reviewers      = median(stars, na.rm = TRUE),
    .groups = "drop"
  )

all_reviewer_summary |>
  left_join(selected_restaurants |> select(business_id, business_name), by = "business_id") |>
  arrange(desc(average_stars_all_reviewers), desc(number_of_reviews_all_reviewers)) |>
  slice_head(n = 10) |>
  mutate(across(where(is.double), \(x) round(x, 2))) |>
  knitr::kable()
```

| business_id | number_of_reviews_all_reviewers | average_stars_all_reviewers | median_stars_all_reviewers | business_name |
|:---|---:|---:|---:|:---|
| n07XNC-z_uWZWG8xJZ8YfA | 12 | 5.00 | 5 | Stella’s Donation Cafe and Coffee Shop |
| 1ODBqsrWYKcby46CHOYjRw | 5 | 5.00 | 5 | Golden Feather Mardi Gras Indian Restaurant Gallery |
| JIMo4CQNZiLYa8Tak4EFiA | 11 | 4.91 | 5 | La Vie En Rose Cafe |
| 7svjXaOKO5638eYiymNP2A | 21 | 4.90 | 5 | Black Star Books & Caffe |
| yAEKaEvsCNxOYv1M1kiQhg | 76 | 4.89 | 5 | Olive |
| ZoRlLcEsxrzfumd6wHa5Jg | 9 | 4.89 | 5 | Chemin a la Mer |
| 2mBzfKvAM4kSU6Gm9WS7lg | 8 | 4.88 | 5 | d4 Tabletop Gaming Cafe |
| tz\_\_wL5D6vb6g3f7Xda84w | 7 | 4.86 | 5 | Mojo Coffee Roasters |
| bK5gt7LHnDjCfZnAGuK0ig | 48 | 4.85 | 5 | Park Island Brew |
| FCcFpitB7F3qxd1bD4Epfg | 40 | 4.85 | 5 | Iacovone Kitchen |

## Select reviewers with enough activity

``` r
reviewer_activity <- category_reviews |>
  count(user_id, name = "reviews_in_selected_categories")

# How the threshold changes what is kept
threshold_table <- map_dfr(c(1, 2, 3, 5, 10, 20), \(k) {
  kept <- reviewer_activity |> filter(reviews_in_selected_categories >= k)
  tibble(
    threshold                     = k,
    reviewers_retained            = nrow(kept),
    percent_of_reviewers          = round(100 * nrow(kept) / nrow(reviewer_activity), 2),
    reviews_retained              = sum(kept$reviews_in_selected_categories),
    percent_of_category_reviews   = round(100 * sum(kept$reviews_in_selected_categories) / nrow(category_reviews), 2)
  )
})
knitr::kable(threshold_table)
```

| threshold | reviewers_retained | percent_of_reviewers | reviews_retained | percent_of_category_reviews |
|---:|---:|---:|---:|---:|
| 1 | 97950 | 100.00 | 159552 | 100.00 |
| 2 | 27047 | 27.61 | 88649 | 55.56 |
| 3 | 11531 | 11.77 | 57617 | 36.11 |
| 5 | 3416 | 3.49 | 30918 | 19.38 |
| 10 | 784 | 0.80 | 14919 | 9.35 |
| 20 | 223 | 0.23 | 7727 | 4.84 |

``` r
activity_threshold <- 5   # Nurislam's choice: at least 5 reviews in the selected categories

eligible_reviewers <- reviewer_activity |>
  filter(reviews_in_selected_categories >= activity_threshold)
```

## Normalize each reviewer’s scores

``` r
reviewer_baselines <- category_reviews |>
  group_by(user_id) |>
  summarise(
    reviewer_mean         = mean(stars, na.rm = TRUE),
    reviewer_median       = median(stars, na.rm = TRUE),
    reviewer_review_count = n(),
    .groups = "drop"
  )

category_reviews_adjusted <- category_reviews |>
  left_join(reviewer_baselines, by = "user_id") |>
  mutate(
    normalized_mean_score   = stars - reviewer_mean,
    normalized_median_score = stars - reviewer_median
  )

eligible_adjusted_reviews <- category_reviews_adjusted |>
  semi_join(eligible_reviewers, by = "user_id")

# How different are the two baselines?
eligible_adjusted_reviews |>
  summarise(
    reviews = n(),
    mean_of_normalized_mean_score   = round(mean(normalized_mean_score), 3),
    mean_of_normalized_median_score = round(mean(normalized_median_score), 3),
    share_of_median_scores_exactly_zero = round(mean(normalized_median_score == 0), 3),
    share_of_mean_scores_exactly_zero   = round(mean(normalized_mean_score == 0), 3)
  ) |>
  knitr::kable()
```

| reviews | mean_of_normalized_mean_score | mean_of_normalized_median_score | share_of_median_scores_exactly_zero | share_of_mean_scores_exactly_zero |
|---:|---:|---:|---:|---:|
| 30918 | 0 | -0.18 | 0.493 | 0.054 |

## Compare raw and reviewer-adjusted results

``` r
restaurant_summary <- selected_restaurants |>
  select(business_id, business_name, stars, latitude, longitude) |>
  left_join(restaurant_area, by = "business_id") |>
  left_join(all_reviewer_summary, by = "business_id") |>
  left_join(
    eligible_adjusted_reviews |>
      group_by(business_id) |>
      summarise(
        number_of_reviews_eligible_reviewers = n(),
        average_stars_eligible_reviewers     = mean(stars, na.rm = TRUE),
        average_normalized_mean_score        = mean(normalized_mean_score, na.rm = TRUE),
        average_normalized_median_score      = mean(normalized_median_score, na.rm = TRUE),
        .groups = "drop"
      ),
    by = "business_id"
  )

min_eligible_reviews <- 10   # Nurislam's choice: at least 10 eligible reviews, because small samples are luck

ranked <- restaurant_summary |>
  filter(number_of_reviews_eligible_reviewers >= min_eligible_reviews) |>
  mutate(
    rank_raw      = min_rank(desc(average_stars_all_reviewers)),
    rank_adjusted = min_rank(desc(average_normalized_median_score)),
    rank_change   = rank_raw - rank_adjusted
  )

tibble(restaurants_with_enough_eligible_reviews = nrow(ranked)) |> knitr::kable()
```

| restaurants_with_enough_eligible_reviews |
|-----------------------------------------:|
|                                      394 |

### Top 10 by raw average (all reviewers)

``` r
ranked |>
  arrange(rank_raw, desc(number_of_reviews_all_reviewers)) |>
  slice_head(n = 10) |>
  select(business_name, area_name, number_of_reviews_all_reviewers, average_stars_all_reviewers,
         number_of_reviews_eligible_reviewers, average_normalized_median_score, rank_raw, rank_adjusted) |>
  mutate(across(where(is.double), \(x) round(x, 2))) |>
  knitr::kable()
```

| business_name | area_name | number_of_reviews_all_reviewers | average_stars_all_reviewers | number_of_reviews_eligible_reviewers | average_normalized_median_score | rank_raw | rank_adjusted |
|:---|:---|---:|---:|---:|---:|---:|---:|
| Park Island Brew | FAIRGROUNDS | 48 | 4.85 | 24 | 0.44 | 1 | 4 |
| Iacovone Kitchen | FRERET | 40 | 4.85 | 15 | 0.47 | 2 | 3 |
| Cafe Porche and snowbar | CENTRAL CITY | 176 | 4.83 | 13 | 0.31 | 3 | 12 |
| Tea Witch Cafe | LOWER GARDEN DISTRICT | 52 | 4.81 | 13 | 0.19 | 4 | 25 |
| Celtica French Bakery | LAKEVIEW | 30 | 4.77 | 15 | 0.40 | 5 | 8 |
| Ck’s Hot Shoppe | CENTRAL CITY | 68 | 4.76 | 12 | 0.33 | 6 | 10 |
| Fatma’s Cozy Corner | TREME - LAFITTE | 129 | 4.74 | 24 | 0.21 | 7 | 21 |
| Catalino’s | EAST CARROLLTON | 75 | 4.73 | 22 | -0.18 | 8 | 187 |
| Piccola Gelateria | WEST RIVERSIDE | 239 | 4.73 | 97 | 0.21 | 9 | 22 |
| Capulet | BYWATER | 50 | 4.72 | 16 | 0.44 | 10 | 4 |

### Top 10 by reviewer-adjusted score (eligible reviewers, median baseline)

``` r
ranked |>
  arrange(rank_adjusted) |>
  slice_head(n = 10) |>
  select(business_name, area_name, number_of_reviews_eligible_reviewers, average_normalized_median_score,
         average_normalized_mean_score, average_stars_all_reviewers, rank_adjusted, rank_raw) |>
  mutate(across(where(is.double), \(x) round(x, 2))) |>
  knitr::kable()
```

| business_name | area_name | number_of_reviews_eligible_reviewers | average_normalized_median_score | average_normalized_mean_score | average_stars_all_reviewers | rank_adjusted | rank_raw |
|:---|:---|---:|---:|---:|---:|---:|---:|
| Shank Charcuterie | MARIGNY | 10 | 0.50 | 0.68 | 4.68 | 1 | 14 |
| Swiss Confectionery | MID-CITY | 18 | 0.47 | 0.72 | 4.42 | 2 | 70 |
| Iacovone Kitchen | FRERET | 15 | 0.47 | 0.67 | 4.85 | 3 | 2 |
| Capulet | BYWATER | 16 | 0.44 | 0.66 | 4.72 | 4 | 10 |
| Park Island Brew | FAIRGROUNDS | 24 | 0.44 | 0.63 | 4.85 | 4 | 1 |
| Angelo Brocato | MID-CITY | 286 | 0.43 | 0.61 | 4.67 | 6 | 16 |
| Corner Muse | LOWER GARDEN DISTRICT | 19 | 0.42 | 0.52 | 4.60 | 7 | 26 |
| Celtica French Bakery | LAKEVIEW | 15 | 0.40 | 0.61 | 4.77 | 8 | 5 |
| Rare Form | MARIGNY | 11 | 0.36 | 0.37 | 3.85 | 9 | 251 |
| Ck’s Hot Shoppe | CENTRAL CITY | 12 | 0.33 | 0.40 | 4.76 | 10 | 6 |

### Largest rank changes after normalization

``` r
ranked |>
  arrange(desc(abs(rank_change))) |>
  slice_head(n = 10) |>
  select(business_name, area_name, number_of_reviews_all_reviewers, number_of_reviews_eligible_reviewers,
         average_stars_all_reviewers, average_normalized_median_score, rank_raw, rank_adjusted, rank_change) |>
  mutate(across(where(is.double), \(x) round(x, 2))) |>
  knitr::kable()
```

| business_name | area_name | number_of_reviews_all_reviewers | number_of_reviews_eligible_reviewers | average_stars_all_reviewers | average_normalized_median_score | rank_raw | rank_adjusted | rank_change |
|:---|:---|---:|---:|---:|---:|---:|---:|---:|
| First Cup Cafe | MARLYVILLE - FONTAINEBLEAU | 54 | 19 | 3.44 | 0.29 | 331 | 15 | 316 |
| Rare Form | MARIGNY | 55 | 11 | 3.85 | 0.36 | 251 | 9 | 242 |
| Louise | MARIGNY | 52 | 12 | 4.21 | -0.62 | 125 | 346 | -221 |
| Gallier Restaurant & Oyster Bar | CENTRAL BUSINESS DISTRICT | 828 | 58 | 4.29 | -0.51 | 108 | 322 | -214 |
| Stuph’D Beignets & Burgers | MILNEBURG | 94 | 21 | 4.49 | -0.33 | 49 | 262 | -213 |
| Streetcar Cafe | CENTRAL BUSINESS DISTRICT | 296 | 16 | 4.39 | -0.44 | 74 | 285 | -211 |
| The Flying Pig Cafe | UPTOWN | 52 | 10 | 4.13 | -0.85 | 161 | 371 | -210 |
| Le Citron Bistro | LOWER GARDEN DISTRICT | 47 | 21 | 3.81 | 0.10 | 260 | 59 | 201 |
| Starbucks | CENTRAL BUSINESS DISTRICT | 131 | 34 | 3.15 | -0.16 | 367 | 176 | 191 |
| Wakin’ Bakin’ | TOURO | 82 | 24 | 4.23 | -0.50 | 122 | 309 | -187 |

``` r
p <- ggplot(ranked, aes(average_stars_all_reviewers, average_normalized_median_score)) +
  geom_hline(yintercept = 0, color = "grey70") +
  geom_point(aes(size = number_of_reviews_all_reviewers), alpha = 0.6) +
  labs(title = "Raw restaurant ratings compared with reviewer-adjusted scores",
       subtitle = paste0("Restaurants with at least ", min_eligible_reviews, " reviews from eligible reviewers"),
       x = "Average stars from all reviewers", y = "Average normalized score (median baseline)",
       size = "Reviews") +
  theme_minimal()
ggsave("figures/step7_raw_vs_adjusted.png", p, width = 8, height = 5, dpi = 150)
p
```

![](steps_7_files/figure-commonmark/raw-vs-adjusted-plot-1.png)

## Neighborhoods: raw vs reviewer-adjusted

``` r
area_summary <- restaurant_summary |>
  filter(!is.na(area_name)) |>
  group_by(area_name) |>
  summarise(
    restaurants                    = n(),
    restaurants_ranked             = sum(number_of_reviews_eligible_reviewers >= min_eligible_reviews, na.rm = TRUE),
    average_business_stars         = mean(stars, na.rm = TRUE),
    average_stars_all_reviewers    = mean(average_stars_all_reviewers, na.rm = TRUE),
    average_normalized_median_score  = mean(average_normalized_median_score[number_of_reviews_eligible_reviewers >= min_eligible_reviews], na.rm = TRUE),
    total_reviews                  = sum(number_of_reviews_all_reviewers, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(rank_raw = min_rank(desc(average_stars_all_reviewers)),
         rank_adjusted = min_rank(desc(average_normalized_median_score)))

area_summary |>
  filter(restaurants >= 10) |>
  arrange(desc(average_normalized_median_score)) |>
  mutate(across(where(is.double), \(x) round(x, 2))) |>
  knitr::kable()
```

| area_name | restaurants | restaurants_ranked | average_business_stars | average_stars_all_reviewers | average_normalized_median_score | total_reviews | rank_raw | rank_adjusted |
|:---|---:|---:|---:|---:|---:|---:|---:|---:|
| WEST RIVERSIDE | 12 | 10 | 4.00 | 4.07 | -0.04 | 1956 | 20 | 10 |
| EAST RIVERSIDE | 11 | 8 | 4.14 | 4.12 | -0.06 | 3755 | 14 | 13 |
| TULANE - GRAVIER | 10 | 8 | 3.95 | 4.00 | -0.07 | 792 | 24 | 14 |
| BYWATER | 21 | 18 | 4.10 | 4.09 | -0.08 | 4385 | 18 | 15 |
| LOWER GARDEN DISTRICT | 28 | 24 | 3.93 | 3.92 | -0.11 | 8556 | 30 | 16 |
| GARDEN DISTRICT | 13 | 13 | 3.92 | 3.92 | -0.15 | 8652 | 29 | 19 |
| AUDUBON | 10 | 9 | 4.05 | 4.01 | -0.15 | 1274 | 23 | 20 |
| MARIGNY | 23 | 17 | 4.04 | 4.06 | -0.19 | 5977 | 21 | 23 |
| LEONIDAS | 14 | 12 | 4.14 | 4.11 | -0.21 | 3821 | 17 | 26 |
| UPTOWN | 12 | 10 | 4.00 | 3.99 | -0.22 | 1802 | 26 | 27 |
| FRENCH QUARTER | 89 | 63 | 3.85 | 3.86 | -0.25 | 48710 | 31 | 31 |
| MID-CITY | 31 | 22 | 3.76 | 3.77 | -0.26 | 5336 | 33 | 32 |
| CENTRAL BUSINESS DISTRICT | 119 | 67 | 3.71 | 3.72 | -0.38 | 42236 | 34 | 37 |
| EAST CARROLLTON | 13 | 12 | 3.42 | 3.45 | -0.45 | 1523 | 42 | 39 |
| CENTRAL CITY | 24 | 15 | 3.42 | 3.41 | -0.46 | 3591 | 43 | 40 |

``` r
nsa_map <- nsa |>
  left_join(area_summary |> mutate(score = if_else(restaurants >= 10, average_normalized_median_score, NA_real_)),
            by = "area_name")
p <- ggplot(nsa_map) +
  geom_sf(aes(fill = score), color = "white", linewidth = 0.15) +
  scale_fill_gradient2(low = "#b2182b", mid = "grey95", high = "#2166ac", midpoint = 0,
                       na.value = "grey85", name = "Avg normalized\nscore") +
  labs(title = "Reviewer-adjusted breakfast & coffee scores by neighborhood",
       subtitle = "Neighborhoods with fewer than 10 selected restaurants are grey") +
  theme_void()
ggsave("figures/step7_area_adjusted_map.png", p, width = 8, height = 6, dpi = 150)
p
```

![](steps_7_files/figure-commonmark/area-map-1.png)

## Final map: top 10

``` r
# Nurislam's choice: "best" is the reviewer-adjusted score (median baseline)
# among restaurants with at least 10 eligible reviews.
top10 <- ranked |> arrange(rank_adjusted) |> slice_head(n = 10) |>
  mutate(label = paste0(row_number(), ". ", business_name))

top10_sf <- top10 |> st_as_sf(coords = c("longitude", "latitude"), crs = 4326) |> st_transform(st_crs(nsa))
bbox <- st_bbox(st_buffer(top10_sf, 0.01))

p <- ggplot() +
  geom_sf(data = nsa, fill = "grey97", color = "grey60", linewidth = 0.2) +
  geom_sf(data = top10_sf, color = "#b2182b", size = 3) +
  ggrepel::geom_label_repel(data = top10, aes(longitude, latitude, label = label), size = 2.6, max.overlaps = 20) +
  coord_sf(xlim = bbox[c("xmin", "xmax")], ylim = bbox[c("ymin", "ymax")]) +
  labs(title = "Top 10 breakfast & coffee places in New Orleans",
       subtitle = "Ranked by reviewer-adjusted score; neighborhood boundaries shown", x = NULL, y = NULL) +
  theme_minimal()
ggsave("figures/step7_top10_map.png", p, width = 8, height = 6, dpi = 150)
p
```

![](steps_7_files/figure-commonmark/top10-map-1.png)
