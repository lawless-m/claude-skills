---
name: RI Credit Pairing
description: Use when counting invoices, orders, trips, buyers or "did we sell it" from Exportmaster sales (analysis), measuring volumes or uplift, or when someone mentions credit notes, credit-and-reinvoice, reversals or credits "double counting" — how to pair a credit note with the invoice it reverses (EM has no coded link), and when plain netting is already enough.
---

# RI Credit Pairing

Most RI credit notes are not refunds. An invoice goes out wrong (delivery note not imported,
customer wants it reissued), it is **credited in full and reinvoiced**, often the same day.
Mike's finding, measured in the DBPrice work (devlog session `beb523c7`, 2026-10-15):

- About 71% of credit lines are reinvoiced the same day. 85% of credited value is full reversals.
- Counting invoices alone overstates quantity by about 6.6% from 2019 (12% in 2022, about 2.6% in 2026).

## When you need it

Credit lines in `analysis` carry **negative** `saval` and `saorgqty` (`sacredit = '1'`, a string;
`sainv` starts `CR`). So `SUM(saval)` / `SUM(saorgqty)` over a period already net credits off. That
is enough for spend and volume totals. Pair credits when you need:
- **document counts**: invoices, trips, order frequency, cases per order. The original and the
  reinvoice both count otherwise.
- **buyer or "did a sale happen" counts**: an invoice credited in full and never reissued isn't a sale.
- **period splits**: the original and its credit can fall in different periods.

## There is no coded link — don't re-investigate

All of these were checked and fail: `analysis.saref` (the credit's own number), `orderi.orgordref`
(blank on every credit line), `orderh.NOTES3` (abandoned after 2021), `orderh.MARKS5` and the free
text in `NOTES`/`NOTES1-2` (about 22% coverage, useful only as a spot check). `orderi.uf_reason`
carries a reason on about 12% of credit lines ("Product temporarily unavailable", "Ordered X
delivered Y"). The link has to be inferred.

## The rule

Pair each credit document with **one** invoice document:
1. same `sacust`, invoice dated on or before the credit (no look-back limit);
2. document totals within 0.5% (or £1), taken over **all** lines, `*` service/freight lines included;
3. at least 90% of the credit's distinct products are on the invoice;
4. of the invoices that pass, closest value, then most recent; one to one, earlier credit wins a contested invoice.

Drop both documents. The reinvoice stays, including Mike's £1,000 / −£1,000 / £1,000 "cosmetic
reissue". Unpaired credits are partial credits (returns, price adjustments): keep them as negative lines.

Why each part exists:
- **Value alone is not proof.** Customers buying the same pallet repeatedly have equal-value
  invoices. Exact value without the product test paired `CR40397` (£24,756) with a same-day invoice
  sharing none of its 22 products. Its real original was `1192363`, two months earlier.
- **Don't stop at the nearest-value candidate.** If it fails the product test, try the next.
  `CR44145` (182 lines, all matching, raised the day after its invoice) is missed by code that gives up.

## Working code

- `credit_pairs.sql` (this folder): DuckDB. Set `START`, run, then use `pairs_matched (c_doc,
  i_doc)`. Checked 2026-10-21 to give exactly the same 2,470 removed documents as the board's M
  version below. In the 4 years to Oct 2026 it pairs 1,235 of 7,600 credits (1,220 at exact value);
  net spend and cases move by under £100 and 300 cases.
- `C:\Sprout\CatKpiTree\board\mrsflow-cgi\catkpi\sales.m`: Power Query M, for MrsFlow boards. Same
  algorithm: a join on customer and 1% value bands, then three rounds of best-pick.
- `C:\Sprout\CatKpiTree\checks\credit_pairing_vs_credits_board.sql`: a sense-check against the
  Credits board, plus a reconciliation with raw `analysis`.

The **Credits board** has its own reversal flag: `\\rivsprod02\RI Services\Scripts\CreditNotes\credit_reasons.sql`
→ `Outputs\Parquets\credits\credit_reasons.parquet`. It covers 2024 onwards only, allows an
invoice up to 30 days *after* the credit, and keeps only the closest-value candidate. On credits
since 2024 the two agree on 537. 108 are flagged by the Credits board only (£24k, mostly that
+30-day window) and 11 by this method only (including `CR40397`, `CR40398`, `CR44145`).

## MrsFlow gotchas (found building the M version)

- A per-customer `List.Accumulate` fold carrying a record state builds fine in the `mrsflow` CLI
  but **overflows `mrsflow-cgi`'s stack** on a big customer (about 1,500 documents). The CGI keeps
  serving the old cache, so it fails quietly. Use joins plus rounds. Test any changed board `.m`
  with a copy of the CGI first: `C:\Sprout\CatKpiTree\scripts\cgi_local.ps1`.
- MrsFlow's `List.Sort` takes a single comparison function only, not a list of sort rules.
  `Table.Sort` with several columns works.
