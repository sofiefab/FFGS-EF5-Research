# Korea_Run — Soyang sub-basin (EF5 / SAC-SMA)

EF5 `basic` grids for a sub-basin of the Soyang Dam watershed (Republic of Korea),
plus the basin boundary used to delineate them.

## Contents

| File | Description |
|------|-------------|
| `dem.tif` | Elevation grid, clipped to the basin bounding box (Float32, m) |
| `ddm.tif` | D8 drainage direction (TauDEM encoding, values **1–8**) |
| `fam.tif` | D8 flow accumulation (cell counts) |
| `SoyangDam.shp/.dbf/.shx/.prj/.qmd` | Sub-basin boundary polygon (WGS84, EPSG:4326) |

## Source DEM

The grids were derived from a regional Korea DEM (`korea_dem.tif`, **not committed** —
1.1 GB, exceeds GitHub limits):

- CRS: WGS84 geographic (EPSG:4326)
- Resolution: 0.000833° = 3 arc-sec ≈ **90 m**
- Native extent: 120–140°E, 30–40°N

## How the grids were produced (reproducible)

Tools: GDAL + TauDEM (with MPI). The DEM is clipped to a **rectangular bounding box**
around the basin (extent from `ogrinfo` + ~0.05° buffer) — *not* a polygon cutline,
so D8 flow accumulation stays hydrologically correct.

```bash
# 1. Clip regional DEM to basin bbox + buffer  (xmin ymin xmax ymax)
gdalwarp -overwrite -te 127.68 37.64 128.64 38.18 -dstnodata -9999 \
         korea_dem.tif dem.tif

# 2. TauDEM D8 chain: fill -> direction -> accumulate
mpiexec -n 4 pitremove -z   dem.tif -fel fel.tif
mpiexec -n 4 d8flowdir -fel fel.tif -p   ddm.tif -sd8 sd8.tif
mpiexec -n 4 aread8    -p   ddm.tif -ad8 fam.tif -nc
```

`fel.tif` (filled DEM) and `sd8.tif` (slope) are TauDEM intermediates and are not committed.

Outlet check: max accumulation inside the basin polygon ≈ 307,206 cells ≈ **2,080 km²**.

## EF5 control-file `[Basic]` block

```ini
[Basic]
DEM=dem.tif
DDM=ddm.tif
FAM=fam.tif
PROJ=geographic
ESRIDDM=false      ; DDM uses TauDEM 1–8 codes (not ESRI 1,2,4,…,128)
SelfFAM=true       ; FAM is in cell counts
```
