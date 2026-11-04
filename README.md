# Project 2: Yelp New Orleans Restaurant Analysis

MATH 167R — investigating where to find the best restaurants in a selected category in New Orleans, using the Yelp Open Dataset. (Research question, category selection, geographic choice, and visualizations are still to be done — see "Project status" below.)

## Project status

This repository currently covers only **Steps 1-2** of the assignment: importing the large raw JSON files and filtering them down to New Orleans restaurants. Steps 3 and beyond (category selection, spatial joins, reviewer normalization, visualizations, final research question and write-up) are not started yet and require design decisions only Nurislam can make.

## Data source and download instructions

This project uses the [Yelp Open Dataset](https://business.yelp.com/data/resources/open-dataset/), specifically:

- `yelp_academic_dataset_business.json`
- `yelp_academic_dataset_review.json`

To reproduce:

1. Download `Yelp-JSON.zip` from <https://business.yelp.com/data/resources/open-dataset/> (direct file link: `https://business.yelp.com/external-assets/files/Yelp-JSON.zip`, about 4.1 GB).
2. Extract the zip. It contains one PDF (the Dataset Challenge/User Agreement document) and five JSON files.
3. Copy (or extract directly) `yelp_academic_dataset_business.json` and `yelp_academic_dataset_review.json` into `data/raw/` in this project. (`yelp_academic_dataset_user.json`, `yelp_academic_dataset_tip.json`, and `yelp_academic_dataset_checkin.json` are not used in this project and can be left out.)
4. Run `R/import.R` then `R/clean_filter.R` from the project root.

The raw JSON files are **not** committed to GitHub — `data/raw/` is in `.gitignore` because these files are several gigabytes and Yelp's terms restrict redistribution. Once `data/new_orleans/*.rds` has been created and verified, the raw files in `data/raw/` can be deleted to free disk space (see the assignment's "large-data management" note — this is why the filtered `.rds` files exist).

## Large-data management notes

- The dataset page gates nothing behind a login or license click-through for the plain-JSON download — it is a direct link. The zip is reported as 4.1 GB; the uncompressed JSON files (all five) are larger again, so disk space should be checked (`df -h`) before downloading.
- `yelp_academic_dataset_review.json` is the large one (several GB, one JSON record per line) — `jsonlite::stream_in()` is used instead of a plain `fromJSON()` read, per the assignment, because it streams the file rather than loading it as one parsed blob.
- Only the columns actually needed are kept immediately after import (`select()`), to cut memory use before any further processing.
- Both the New Orleans-restaurant-filtered business table and the reviews filtered down to just those business IDs are saved as `compress = "xz"` `.rds` files in `data/new_orleans/`, so later work (Steps 3+) does not need to re-parse the raw JSON, and the multi-gigabyte raw files can eventually be deleted.

## Files and folders

| Path | Purpose |
|---|---|
| `R/import.R` | Step 1 — streams in `business.json` and `review.json` from `data/raw/`, keeps only the needed columns. |
| `R/clean_filter.R` | Step 2 — filters businesses to New Orleans restaurants (`state == "LA"`, `city == "New Orleans"`, categories containing "Restaurants"), dedupes, saves filtered business and review tables as `.rds`. |
| `data/raw/` | Downloaded raw Yelp JSON files. Gitignored, not committed. |
| `data/new_orleans/` | Filtered output: `business_new_orleans.rds`, `reviews_new_orleans.rds`. |
| `AI_PROMPTS_LOG.md` | Record of AI prompts used on this project (see `AI_PROMPTS_LOG_DRAFT.md` for the entry covering this import/filter setup, pending Nurislam's review). |

## AI use

AI-assisted setup for this import/filter step is logged in `AI_PROMPTS_LOG_DRAFT.md`, to be folded into the final `AI_PROMPTS_LOG.md`.
