# RI territory membership

From `rigeographic`, 2026-10-21. Countries are distinct country codes; a country can have several
region rows. No country sits in two territories.

| Code | Territory | Countries | Continents | Country codes |
|---|---|---:|---|---|
| AI | Atlantic Islands | 4 | Africa, South America | FK GS IC SH |
| AN | Anglophone Africa | 21 | Africa | BW ER ET GH GM KE LR LS MU NA NG SC SD SL SO SZ TZ UG ZA ZM ZW |
| AS | South-East Asia | 10 | Asia | BN ID KH LA MY SG TH TL TP VN |
| BE | Benelux | 3 | Europe | BE LU NL |
| CA | Caribbean | 27 | North America, South America | AG AI AN AW BB BM BS BZ CW DM GD GF GP GY HT JM KN KY LC MQ MS SR TC TT VC VG VI |
| CE | Central Europe | 4 | Europe | AT CH DE LI |
| EA | East Asia | 8 | Asia | CN HK JP KP KR MN MO TW |
| EE | Eastern Europe | 30 | Asia, Europe | AL AM AZ BA BG BY CZ EE GE HR HU KG KZ LT LV MD ME MK PL RO RS RU SI SK TJ TM UA UZ XK XS |
| EM | Eastern Mediterranean | 5 | Asia, Europe | CY EL GR MT TR |
| FA | Francophone Africa | 21 | Africa | BF BI BJ CF CG CI CM DJ GA GN KM MG ML MW NE RE RW SN TD TG YT |
| FI | France & Italy | 6 | Europe, North America | FR IT MC PM SM VA |
| GB | GB/Ireland | 2 | Europe | GB IE |
| IB | Iberia | 6 | Africa, Europe | AD ES GI PT XC XL |
| LA | Latin America | 19 | North America, South America | AR BO BR CL CO CR CU DO EC GT MX NI PA PE PR PY SV UY VE |
| LU | Lusophone Africa | 7 | Africa | AO CV GQ GW MR MZ ST |
| ME | Middle East | 22 | Africa, Asia | AE AF BH DH DU DZ EG IL IQ IR JO KW LB LY MA OM PS QA SA SY TN YE |
| NA | North America | 2 | North America | CA US |
| OP | Oceania/Pacific | 21 | Oceania | AU FJ FM KI MH MP NC NF NR NZ PF PG PN PW SB TK TO TV VU WF WS |
| SA | South Asia | 8 | Asia | BD BT IN IO LK MV NP PK |
| SC | Scandinavia | 7 | Europe, North America | DK FI FO GL IS NO SE |
| SE | South East Asia | 2 | Asia | MM PH |
| XX | United Kingdom | 1 | Europe | UK |

Multi-region countries: GB (21 regions, one "UK <territory>" per territory plus GBGBAA UK
Collections Only), FR (12, France Alps … France West, plus FIFRZZ which is Monaco), AE (8, one per
emirate), ES (7, Andalucia, Balearics, Catalunia, Madrid, Valencia/Murcia, Rest of Spain,
Unspecified), US (4, North East, South East, West, Unspecified), TR (3, All, Mainland, Northern
Cyprus).

To refresh this table:

```sql
SELECT riterritorycode, riterritorydesc, count(DISTINCT countrycode) AS countries,
       string_agg(DISTINCT continentname, ', ' ORDER BY continentname) AS continents,
       string_agg(DISTINCT countrycode, ' ' ORDER BY countrycode) AS country_codes
FROM read_parquet('//rivsprod02/RI Services/Outputs/Parquets/em/rigeographic.parquet')
GROUP BY 1, 2 ORDER BY 1;
```
