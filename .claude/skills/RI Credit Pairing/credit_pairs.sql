-- Credit-and-reinvoice pairing for Exportmaster sales, in DuckDB.
-- Same rules and result as the Category KPI board's sales.m (C:\Sprout\CatKpiTree), checked
-- against it 2026-10-21: identical set of removed documents.
--
-- Input:  the EM analysis parquet, from START (allow ~90 days before the period you report,
--         so early credits can reach their original).
-- Output: TEMP TABLE pairs_matched (c_doc, i_doc, gap) -- one row per credit paired with the
--         invoice it reverses. Remove BOTH documents from volume / trip / buyer work; the
--         reinvoice stays. Credits not in pairs_matched are partial credits: keep them as
--         negative lines.
--
-- Run:  duckdb -f credit_pairs.sql   (edit START first), then query pairs_matched, e.g.
--       SELECT * FROM analysis_view WHERE sainv NOT IN (SELECT c_doc FROM pairs_matched UNION SELECT i_doc FROM pairs_matched)
SET VARIABLE START = DATE '2022-07-23';

CREATE OR REPLACE TEMP TABLE an AS
SELECT sainv, sacust, sacredit, sadate, saproduct, saval
FROM read_parquet('//rivsprod02/RI Services/Outputs/Parquets/em/analysis.parquet')
WHERE sadate >= getvariable('START');

-- Document totals over ALL lines (services/freight '*' lines included: they are on the
-- invoice and on the credit), and each document's products for the overlap test.
CREATE OR REPLACE TEMP TABLE docs AS
SELECT sainv AS doc, any_value(sacust) AS cust, any_value(sacredit) AS cr, min(sadate) AS dt,
       round(sum(saval), 2) AS val, list(DISTINCT saproduct) AS prods
FROM an GROUP BY 1;

-- Candidates: same customer, invoice on or before the credit, totals within 0.5% (or £1),
-- and at least 90% of the credit's products on the invoice. Credit totals are negative.
CREATE OR REPLACE TEMP TABLE pairs_left AS
SELECT c.doc AS c_doc, c.dt AS c_dt, i.doc AS i_doc, i.dt AS i_dt, abs(i.val + c.val) AS gap
FROM docs c
JOIN docs i
  ON i.cust = c.cust AND i.cr = '0' AND i.val > 0 AND i.dt <= c.dt
 AND i.val BETWEEN -c.val - greatest(1, -c.val * 0.005) AND -c.val + greatest(1, -c.val * 0.005)
WHERE c.cr = '1' AND c.val < 0
  AND abs(i.val + c.val) < greatest(1, -c.val * 0.005)
  AND len(list_intersect(c.prods, i.prods)) >= 0.9 * len(c.prods);

-- One to one, in rounds: each credit picks its closest-value then most recent invoice; if
-- two credits pick the same invoice the earlier credit wins; losers retry with what's left.
CREATE OR REPLACE TEMP TABLE pairs_matched (c_doc VARCHAR, i_doc VARCHAR, gap DOUBLE);
CREATE OR REPLACE TEMP MACRO round_winners() AS TABLE
  SELECT c_doc, i_doc, gap FROM (
    SELECT * FROM pairs_left
    QUALIFY row_number() OVER (PARTITION BY c_doc ORDER BY gap, i_dt DESC, i_doc) = 1)
  QUALIFY row_number() OVER (PARTITION BY i_doc ORDER BY c_dt, c_doc) = 1;

INSERT INTO pairs_matched SELECT * FROM round_winners();
DELETE FROM pairs_left WHERE c_doc IN (SELECT c_doc FROM pairs_matched) OR i_doc IN (SELECT i_doc FROM pairs_matched);
INSERT INTO pairs_matched SELECT * FROM round_winners();
DELETE FROM pairs_left WHERE c_doc IN (SELECT c_doc FROM pairs_matched) OR i_doc IN (SELECT i_doc FROM pairs_matched);
INSERT INTO pairs_matched SELECT * FROM round_winners();

SELECT count(*) AS credits_paired, count(*) FILTER (WHERE gap = 0) AS exact_value,
       (SELECT count(*) FROM docs WHERE cr = '1') AS credits_in_window
FROM pairs_matched;
