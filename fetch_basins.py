"""
SAOFFGS basin-value pipeline (ArcGIS FeatureServer only).

Pulls all basins from the BMKG SAOFFGS "Spartan BASIN" FeatureServer and
writes per-basin flash-flood-risk values (ffr12 / ffr24) to a timestamped CSV.

Data source:
  https://datacuaca.bmkg.go.id/arcgis/rest/services/production/saoffg/FeatureServer/0

CSV columns: basin_id, ffr12, ffr24, status, timestamp
Standard library only (urllib, csv, json) -- no third-party packages required.
"""

import csv
import json
import os
import ssl
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timezone

LAYER_URL = ("https://datacuaca.bmkg.go.id/arcgis/rest/services/"
             "production/saoffg/FeatureServer/0/query")
OUT_DIR = os.path.dirname(os.path.abspath(__file__))
PAGE_SIZE = 2000
TIMEOUT = 60

_CTX = ssl.create_default_context()


def _get(params):
    url = LAYER_URL + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": "ffgs-benchmark/1.0"})
    with urllib.request.urlopen(req, timeout=TIMEOUT, context=_CTX) as r:
        return json.loads(r.read().decode("utf-8"))


def fetch_all_basins():
    """Page through the layer and return a list of attribute dicts."""
    rows = []
    offset = 0
    while True:
        data = _get({
            "where": "1=1",
            "outFields": "value,ffr12,ffr24,status",
            "returnGeometry": "false",
            "orderByFields": "objectid",
            "resultOffset": offset,
            "resultRecordCount": PAGE_SIZE,
            "f": "json",
        })
        if "error" in data:
            raise RuntimeError("ArcGIS error: %s" % data["error"])
        feats = data.get("features", [])
        if not feats:
            break
        rows.extend(f["attributes"] for f in feats)
        if not data.get("exceededTransferLimit") and len(feats) < PAGE_SIZE:
            break
        offset += len(feats)
    return rows


def write_csv(rows, retrieved_ts):
    fname = "saoffgs_basins_%s.csv" % retrieved_ts.strftime("%Y%m%dT%H%M%SZ")
    path = os.path.join(OUT_DIR, fname)
    iso = retrieved_ts.isoformat()
    with open(path, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["basin_id", "ffr12", "ffr24", "status", "timestamp"])
        for a in rows:
            w.writerow([a.get("value"), a.get("ffr12"), a.get("ffr24"),
                        a.get("status"), iso])
    return path


def main():
    retrieved_ts = datetime.now(timezone.utc)
    rows = fetch_all_basins()
    path = write_csv(rows, retrieved_ts)

    size = os.path.getsize(path)
    print("rows written : %d" % len(rows))
    print("file         : %s" % path)
    print("file size    : %d bytes (%.1f KB)" % (size, size / 1024))
    print("first 3 rows :")
    with open(path, encoding="utf-8") as fh:
        for line in list(fh)[:4]:   # header + 3 data rows
            print("  " + line.rstrip())


if __name__ == "__main__":
    sys.exit(main())
