---
name: RI Territories
description: Use when grouping RI sales or any country data by RI territory, joining rigeographic, reading the territory or country out of an Exportmaster region code (saterr), or when someone names a territory ("LA", "the Caribbean", "Anglophone Africa") — RI's 22 territories, their codes, membership and the traps in them.
---

# RI Territories

RI sells by **territory**: 22 groups of countries, each with a two-letter code (LA = Latin America,
CA = Caribbean). The definitions live in **`rigeographic`**, written nightly by the Exportmaster
export:

`\\rivsprod02\RI Services\Outputs\Parquets\em\rigeographic.parquet` (= `R:\Outputs\Parquets\em\…`)

Columns: `regioncode, countrycode, riterritorycode, riterritorydesc, continentname, countryname,
regiondesc, rinewanalysisterr`. Sales are in `analysis.parquet` in the same folder; `saterr` is the
region code. Full membership: `reference-membership.md`. Checked against the data 2026-10-21.

## The traps

- **One row per region, not per country.** 285 rows, 236 country codes. GB has 21 rows, FR 12,
  AE 8, ES 7, US 4, TR 3. Reduce to `DISTINCT countrycode, riterritorycode` before joining, or
  totals multiply.
- **Region code = territory + country + sub-region**: `IBESVM` = IB, ES, Valencia/Murcia. The
  territory prefix holds for every region. The country part does not for **`FIFRZZ` = Monaco
  (MC)**, so `substr(saterr, 3, 2)` books Monaco as France. Join `saterr` to `regioncode` instead
  of slicing it. A few legacy 4-character `saterr` values (`FKAA`, `GBME`; about £10k in 2020–2025)
  are in no region.
- **Territory codes collide with country codes.** CA Caribbean / Canada, AN Anglophone Africa /
  Netherlands Antilles, NA North America / Namibia, LA Latin America / Laos, SE South East Asia /
  Sweden, GB GB/Ireland / United Kingdom, plus AI, BE, EE, FI, LU, ME, SA, SC. Say "territory CA
  (Caribbean)" and keep the two code columns apart.
- **Two South-East Asias**: AS "South-East Asia" (10 countries) and SE "South East Asia" (MM, PH only).
- **Two UKs**: territory XX "United Kingdom" holds country code UK; territory GB "GB/Ireland" holds GB and IE.
- **UK-collected orders for a territory.** GB has a region per territory, "UK <territory>"
  (`GBGBME` UK Middle East, `GBGBCA` UK Caribbean …), plus `GBGBAA` UK Collections Only. 2020–2025:
  £21.8m on GBGBAA, £2.1m UK Middle East, £330k UK Caribbean, under £50k on the rest. Dropping GB as
  "not an export" loses these; decide deliberately.
- **Territories cross continents**: EE runs into Asia, LA and CA span both Americas, FI includes
  Saint Pierre (North America), IB includes Ceuta/Melilla (Africa), SC includes Greenland, ME
  covers North Africa. Pick by territory **or** continent, never nest one in the other.
- **Duplicate and legacy country codes**, all present: EL and GR (Greece; EL is the EU code RI uses,
  HMRC uses GR), RS and XS (Serbia; HMRC uses XS), TP and TL (East Timor), DU and DH beside AE
  (UAE), AN (Netherlands Antilles, dissolved 2010), UK and GB. Names include "Greece (GR)" and
  "Dubai (Should Be United Arab Emirates)".
- **`rinewanalysisterr` is not a clean roll-up.** "Africa" mixes FA, LU, AN, IB, AI and NA (US
  "Unspecified Region" is tagged Africa); FI splits across three groups; it is spelt "Carribean".
  Use `riterritorycode` unless the analysis grouping is asked for by name.

## The TradeMap country policy

TradeMap (`C:\Sprout\Trademap`, decided 2026-10-13) maps EL→GR, RS→XS, TP→TL, DU/DH→AE and drops
GB, UK, AA (a stray code) and AN, so RI's codes meet HMRC's. Reuse it when matching RI to HMRC
data; the SQL is the `view_country_policy` section of `board/trademap.html`.
