# import.R
# Step 1 of the Yelp New Orleans project: import the large raw JSON files
# and keep only the columns needed for the rest of the analysis.
#
# Usage: run from the project root (not from inside data/raw/), e.g.
#   Rscript R/import.R
# or source it from an interactive R session / the final .qmd report.
#
# Security note: the files in data/raw/ are downloaded, untrusted data.
# This script only ever reads them — it does not execute anything found
# inside them — and all paths below are passed in explicitly rather than
# relying on a working directory inside data/raw/.
#
# MEMORY NOTE (deviation from the assignment's literal Step 1 code block,
# flagged for Nurislam to confirm): this machine has 8GB RAM. Reading the
# whole 5.3GB review.json into memory in one `stream_in()` call (as the
# assignment's example code does) pushed the system into real, growing
# swap usage during testing. So business.json (118MB — small, safe) is
# still imported here in one shot, but review.json is now imported
# chunk-by-chunk together with the New Orleans filter in clean_filter.R,
# instead of being fully loaded here first. The assignment's own
# "large-data management" section explicitly names "processing the
# review file in chunks" as an acceptable solution for exactly this
# situation, so this is a different implementation of the same step, not
# a different step.

library(tidyverse)
library(jsonlite)

business_file <- "data/raw/yelp_academic_dataset_business.json"
review_file   <- "data/raw/yelp_academic_dataset_review.json"

if (!file.exists(business_file)) {
  stop(
    "Missing ", business_file, ".\n",
    "Download the Yelp Open Dataset from ",
    "https://business.yelp.com/data/resources/open-dataset/ and extract ",
    "yelp_academic_dataset_business.json into data/raw/ before running this script."
  )
}
if (!file.exists(review_file)) {
  stop(
    "Missing ", review_file, ".\n",
    "Download the Yelp Open Dataset and extract ",
    "yelp_academic_dataset_review.json into data/raw/ before running this script."
  )
}

# --- Business table (small file, imported whole, as the assignment shows) -

business_raw <- jsonlite::stream_in(
  file(business_file),
  verbose = FALSE
)

business <- business_raw |>
  select(
    business_id, name, address, city, state, postal_code,
    latitude, longitude, stars, review_count, categories
  )

rm(business_raw)
gc()

dim(business)
glimpse(business)
head(business, 3)

# --- Review table ---------------------------------------------------------
# NOT imported here in full — see clean_filter.R, which reads review.json
# in chunks and filters each chunk down to New Orleans restaurants before
# the next chunk is loaded, so the full ~6.9M-row table is never held in
# memory at once. `review_file` (defined above) is reused there.
