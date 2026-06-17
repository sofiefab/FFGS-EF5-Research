# SAOFFGS Benchmarking Pipeline

This project benchmarks the Southeast Asia-Oceania Flash Flood Guidance System
(SAOFFGS). It pulls per-basin flash-flood-risk values from the public BMKG
ArcGIS service, then saves them to a timestamped CSV for analysis.

## Data source

- BMKG Indonesia
- WMO FFGS Programme
- Korea-WMO FFGS Initiative
- Public ArcGIS REST API:
  `https://datacuaca.bmkg.go.id/arcgis/rest/services/production/saoffg/FeatureServer/0`

## How to run

```
python fetch_basins.py
```

## Output

A CSV with one row per basin and the columns:

`basin_id, ffr12, ffr24, status, timestamp`
