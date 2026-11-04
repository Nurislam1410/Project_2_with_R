# clean_filter.R
# Step 2 of the Yelp New Orleans project: filter the full business table
# down to New Orleans restaurants, then filter reviews down to just those
# restaurants' reviews. Saves both as compressed .rds files so the huge
# raw JSON does not need to be re-parsed on every run.
#
# Usage: run from the project root after R/import.R has created the
# `business` object, e.g.
#   Rscript -e "source('R/import.R'); source('R/clean_filter.R')"
# or source both in order inside the final .qmd report.
#
# MEMORY NOTE (deviation from the assignment's literal code, flagged for
# Nurislam to confirm): on this 8GB-RAM machine, reading all of
# review.json (5.3GB, ~6.9M rows) into memory at once before filtering
# caused real, growing swap usage. So this script reads review.json in
# chunks with jsonlite::stream_in()'s `handler` argument: each chunk is
# read, immediately reduced to the needed columns, and immediately
# semi_join-filtered down to only the New Orleans restaurant business_ids
# (computed from `business` first, below) *before* the next chunk loads.
# Only the small, already-filtered result accumulates across chunks — the
# full unfiltered review table is never held in memory at once. This is
# the "processing the review file in chunks" solution the assignment's
# own "large-data management" section names as acceptable for a
# memory-constrained computer.

library(tidyverse)
library(jsonlite)

review_file <- "data/raw/yelp_academic_dataset_review.json"

# --- Filter business table to New Orleans restaurants ----------------------
# (Same filter the assignment's Step 2 code block shows, unchanged.)

new_orleans_restaurants <- business |>
  filter(
    state == "LA",
    city == "New Orleans",
    !is.na(categories),
    str_detect(categories, regex("Restaurants", ignore_case = TRUE))
  ) |>
  mutate(
    postal_code = na_if(postal_code, ""),
    categories = str_squish(categories),
    business_name = str_squish(name)
  ) |>
  distinct(business_id, .keep_all = TRUE)

new_orleans_restaurants |>
  summarise(
    number_of_restaurants = n(),
    missing_latitude = sum(is.na(latitude)),
    missing_longitude = sum(is.na(longitude)),
    missing_categories = sum(is.na(categories))
  )

dir.create("data/new_orleans", recursive = TRUE, showWarnings = FALSE)

saveRDS(
  new_orleans_restaurants,
  "data/new_orleans/business_new_orleans.rds",
  compress = "xz"
)

nola_ids <- new_orleans_restaurants |> select(business_id)

# --- Chunked read + filter of review.json -----------------------------------

matched_chunks <- list()
total_rows_scanned <- 0
first_chunk_for_glimpse <- NULL

review_handler <- function(chunk) {
  total_rows_scanned <<- total_rows_scanned + nrow(chunk)

  chunk_slim <- chunk |>
    select(business_id, user_id, stars, date, text, useful, funny, cool)

  if (is.null(first_chunk_for_glimpse)) {
    first_chunk_for_glimpse <<- head(chunk_slim, 3)
  }

  matched <- chunk_slim |> semi_join(nola_ids, by = "business_id")

  if (nrow(matched) > 0) {
    matched_chunks[[length(matched_chunks) + 1]] <<- matched
  }

  invisible(NULL)
}

jsonlite::stream_in(
  file(review_file),
  handler = review_handler,
  pagesize = 50000,
  verbose = FALSE
)

new_orleans_reviews <- bind_rows(matched_chunks)
rm(matched_chunks)
gc()

cat("Total review records scanned (full file, before filtering):", total_rows_scanned, "\n")
cat("\nSample of the raw review schema (first chunk, 3 rows, before filtering):\n")
print(first_chunk_for_glimpse)

dim(new_orleans_reviews)
glimpse(new_orleans_reviews)

saveRDS(
  new_orleans_reviews,
  "data/new_orleans/reviews_new_orleans.rds",
  compress = "xz"
)

# read them back in later, e.g. in the .qmd report:
# new_orleans_restaurants <- readRDS("data/new_orleans/business_new_orleans.rds")
# new_orleans_reviews     <- readRDS("data/new_orleans/reviews_new_orleans.rds")
