# AI Prompts Log — Project 2 (Yelp New Orleans)

Tool: Claude Code. This log was compiled by Claude from the record of my sessions, at my request; prompts in quotation marks are my own words, others are summarized. Detailed technical notes for Steps 1-6 are in `AI_PROMPTS_LOG_DRAFT.md`.

## 1. Steps 1-2: import and filter setup (2026-11-03)

- **Prompt (summary):** Set up the repository, download the Yelp Open Dataset, and write the Step 1 import and Step 2 New Orleans restaurant filter, following the assignment's example code.
- **What came back:** `R/import.R` and `R/clean_filter.R`; 2,259 restaurants and 476,421 reviews saved as compressed `.rds` files.
- **Iteration:** the assignment's one-shot `stream_in()` made the computer run out of memory, so the review file was read in 50,000-row chunks instead (an option the assignment allows).

## 2. Steps 3-6: category selection, joins and geography (2026-11-10)

- **Prompt (summary):** I chose the theme, breakfast and coffee places, and asked for the Step 3-6 tables and maps so I could compare the geographic systems.
- **What came back:** 575 places in four categories, 159,552 reviews, 564 inside the city boundary, and a comparison of ZIP codes, Census tracts and Neighborhood Statistical Areas.
- **Iteration:** I wrote the Step 6 explanation of which geographic system to use myself, then asked Claude to place it in the report and "verify I did not miss anything else, and fix the report accordingly to avoid mislead of what is left in it." That check found two misleading lines (the tract-map sentence, and what "cafes" meant), which were corrected.

## 3. Step 7: reviewer normalization (2026-11-15)

- **Prompt (summary):** Compute the all-reviewer and eligible-reviewer results with provisional settings, and leave the four decisions to me.
- **Iteration on my decisions:**
  - Activity threshold: I chose **5 reviews per reviewer**, because 5 reviews proves better the authenticity of the reviewer and his or her experience.
  - Baseline: I chose the **median**, because the median better explains where the middle is.
  - Definition of "best": I first answered "raw stars?". Claude asked which part of Step 7 a raw-star ranking would ignore, and I changed it to the **reviewer-adjusted score**.
  - Minimum eligible reviews per restaurant: I asked "why not to 10?". Claude measured both (492 restaurants ranked at 5, 394 at 10, and the top 10 at 5 was mostly places with 5-7 reviews), and I chose **10**, "because small samples are luck."
- **What came back:** Step 7 re-run with these settings (`steps_7.qmd`, `steps_7.md`, `figures/step7_*.png`).

## What I verified myself

The Step 6 explanation and the four Step 7 decisions are mine. The code was produced with Claude Code, and the parts I still have to finish are listed under "Project status" in the README.
