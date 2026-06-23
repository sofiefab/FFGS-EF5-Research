#!/usr/bin/env bash
###############################################################################
# make_basic_grids.sh
# -----------------------------------------------------------------------------
# Build the three EF5 "basic" grids (DEM, DDM, FAM) from a regional DEM and a
# basin boundary shapefile, using GDAL + TauDEM.
#
# Pipeline:
#   1. clip regional DEM to the basin bounding box + buffer  (gdalwarp -te)
#   2. fill pits                                             (pitremove)
#   3. D8 flow direction  -> DDM (values 1-8)               (d8flowdir)
#   4. D8 flow accumulation -> FAM (cell counts)            (aread8)
#
# IMPORTANT: we clip to a RECTANGULAR bbox (not the polygon cutline). A polygon
# cutline nulls cells outside the basin, so edge cells drain off-map and the
# accumulation comes out wrong. A closed basin still drains to its outlet with
# surrounding land included, so the rectangle is both safe and correct.
#
# Requirements (on PATH): gdalwarp, gdalinfo, ogrinfo, mpiexec,
#                         pitremove, d8flowdir, aread8
#   conda:  conda create -n hydro -c conda-forge taudem gdal && conda activate hydro
#
# Usage:
#   ./make_basic_grids.sh -d korea_dem.tif -s SoyangDam.shp -o ./basic
#   ./make_basic_grids.sh -d dem.tif -s basin.shp -o out -b 0.05 -n 4
#   ./make_basic_grids.sh -d dem.tif -e "127.68 37.64 128.64 38.18" -o out
#
# Options:
#   -d  regional DEM (GeoTIFF)                     [required]
#   -o  output directory                           [required]
#   -s  basin boundary shapefile (for bbox)        [required unless -e given]
#   -e  explicit bbox "xmin ymin xmax ymax"        [overrides -s extent]
#   -b  buffer in degrees added around bbox        [default 0.05  (~5 km)]
#   -n  number of MPI processes                    [default 4]
###############################################################################
set -euo pipefail

DEM=""; SHP=""; OUT=""; BBOX=""; BUF="0.05"; N="4"
while getopts "d:s:o:e:b:n:h" opt; do
  case "$opt" in
    d) DEM="$OPTARG" ;;
    s) SHP="$OPTARG" ;;
    o) OUT="$OPTARG" ;;
    e) BBOX="$OPTARG" ;;
    b) BUF="$OPTARG" ;;
    n) N="$OPTARG" ;;
    h) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Run '$0 -h' for help." >&2; exit 1 ;;
  esac
done

[ -n "$DEM" ] || { echo "ERROR: -d DEM is required." >&2; exit 1; }
[ -n "$OUT" ] || { echo "ERROR: -o OUTDIR is required." >&2; exit 1; }
[ -f "$DEM" ] || { echo "ERROR: DEM not found: $DEM" >&2; exit 1; }
mkdir -p "$OUT"

# --- 1. Determine the bounding box ------------------------------------------
if [ -z "$BBOX" ]; then
  [ -n "$SHP" ] || { echo "ERROR: provide -s SHAPEFILE or -e BBOX." >&2; exit 1; }
  [ -f "$SHP" ] || { echo "ERROR: shapefile not found: $SHP" >&2; exit 1; }
  # Parse "Extent: (xmin, ymin) - (xmax, ymax)" from ogrinfo, then add buffer.
  read -r XMIN YMIN XMAX YMAX < <(
    ogrinfo -so -al "$SHP" | awk -v b="$BUF" '
      /Extent:/ {
        gsub(/[(),-]/, " ");        # strip punctuation
        print $2-b, $3-b, $4+b, $5+b # xmin ymin xmax ymax, buffered
      }')
  BBOX="$XMIN $YMIN $XMAX $YMAX"
fi
echo ">> bounding box (xmin ymin xmax ymax): $BBOX"

# --- 2. Clip regional DEM to the rectangular bbox ---------------------------
echo ">> [1/4] clip DEM -> $OUT/dem.tif"
gdalwarp -overwrite -te $BBOX -dstnodata -9999 \
  -co COMPRESS=LZW -co TILED=YES "$DEM" "$OUT/dem.tif"

# --- 3. TauDEM D8 chain -----------------------------------------------------
echo ">> [2/4] pitremove -> $OUT/fel.tif"
mpiexec -n "$N" pitremove -z "$OUT/dem.tif" -fel "$OUT/fel.tif"

echo ">> [3/4] d8flowdir -> $OUT/ddm.tif (DDM, values 1-8)"
mpiexec -n "$N" d8flowdir -fel "$OUT/fel.tif" -p "$OUT/ddm.tif" -sd8 "$OUT/sd8.tif"

echo ">> [4/4] aread8 -> $OUT/fam.tif (FAM, cell counts)"
mpiexec -n "$N" aread8 -p "$OUT/ddm.tif" -ad8 "$OUT/fam.tif" -nc

# --- 4. Report --------------------------------------------------------------
echo ">> done. DDM range (should be 1..8):"
gdalinfo -stats "$OUT/ddm.tif" | grep -E "STATISTICS_(MINIMUM|MAXIMUM)"
echo ">> FAM range (max = cells draining to lowest outlet):"
gdalinfo -stats "$OUT/fam.tif" | grep -E "STATISTICS_(MINIMUM|MAXIMUM)"

cat <<EOF

EF5 [Basic] block for the control file:
  DEM=dem.tif
  DDM=ddm.tif
  FAM=fam.tif
  PROJ=geographic
  ESRIDDM=false     ; DDM uses TauDEM 1-8 codes
  SelfFAM=true      ; FAM is cell counts

(fel.tif and sd8.tif are TauDEM intermediates - safe to delete.)
EOF
