#!/bin/bash
set -e

# ==============================================================================
# INITIAL ENVIRONMENT SETUP
# ==============================================================================
# Expose system paths so background processes can find git, curl, and python
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
export HOME="/Users/eknlau"

echo "=================================================================="
echo "   CWA MESOSCALE DOWNLOAD & ANALYSIS DAEMON                      "
echo "   Triggered via Crontab Environment                             "
echo "=================================================================="

echo "=================================================================="
echo "   CWA MESOSCALE DOWNLOAD & ANALYSIS DAEMON (RUNNING PIPELINE)   "
echo "=================================================================="
echo "--- 任務開始: $(date) ---"

# ==============================================================================
# DIRECTORY SAFEGUARD
# ==============================================================================
cd "/Users/eknlau/VS_code/GHMWS-meso-model"

# ==============================================================================
# CONFIGURATION
# ==============================================================================
BRANCH="main"
githubUser="eknlau5897"
githubRepo="GHMWS-meso-model"

SAVE_DIR="/Users/eknlau/Desktop/CWA/accu_rain"
SAVE_DIR_2="/Users/eknlau/VS_code/GHMWS-meso-model/model/CWA/accu_rain"

mkdir -p "$SAVE_DIR"
mkdir -p "$SAVE_DIR_2"

# ==============================================================================
# 0. RE-ALIGN PLUMBING LOCKS BEFORE DOWNLOADING
# ==============================================================================
if [ ! -d ".git" ]; then
    echo "[Repo Guard] Setting up pristine Git plumbing matrix..."
    git init
    git checkout -b "$BRANCH"
fi

git remote remove origin 2>/dev/null || true
git remote add origin "https://github.com/${githubUser}/${githubRepo}.git"

# ==============================================================================
# 1. DATA PROCESSOR MATRIX (HERBIE & CFGRIB MULTI-PARSER SYSTEM)
# ==============================================================================
URL="https://cwaopendata.s3.ap-northeast-1.amazonaws.com/Model"
PREFIX="M-A0064"

for j in $(seq 0 6 84); do
    i=$(printf "%03d" $j)
    
    SOURCE_FILE="${PREFIX}-${i}.grb2"
    FILE_PATH="${SAVE_DIR}/${i}.grb2"
    IMAGE_PATH="${SAVE_DIR_2}/${j}.png"

    echo "📥 Downloading ${SOURCE_FILE}..."
    curl -L "${URL}/${SOURCE_FILE}" -o "${FILE_PATH}"

    export EXP_FILE_PATH="${FILE_PATH}"
    export EXP_IMAGE_PATH="${IMAGE_PATH}"
    export EXP_J_VAL="${j}"

    /opt/anaconda3/bin/python << 'EOF_PYTHON'
import os
import matplotlib
matplotlib.use('Agg') 
import xarray as xr
import numpy as np
import matplotlib.pyplot as plt
import cartopy.crs as ccrs
import cartopy.feature as cfeature
import cfgrib
import pandas as pd
from herbie import Herbie
from herbie.toolbox import EasyMap, pc
from herbie import paint

f_path = os.environ['EXP_FILE_PATH']
img_path = os.environ['EXP_IMAGE_PATH']
j_val = os.environ['EXP_J_VAL']

try:
    datasets = cfgrib.open_datasets(f_path)
    data = datasets[4]
    
    fig = plt.figure(figsize=(12, 12))
    ax = plt.axes(projection=ccrs.PlateCarree())

    ax.add_feature(cfeature.STATES.with_scale('10m'), linewidths=0.5, edgecolor='k')
    ax.add_feature(cfeature.BORDERS.with_scale('10m'), linewidths=1.0, edgecolor='k')
    ax.add_feature(cfeature.COASTLINE.with_scale('10m'), linewidths=1.0, edgecolor='k')
    ax.add_feature(cfeature.LAND.with_scale('10m'), facecolor='#EEEEEE')

    p = ax.contourf(
        data.longitude, data.latitude, data.unknown,
        transform=ccrs.PlateCarree(),
        cmap='radar.reflectivity',
        extend='max',
        levels=[0.1,1,2,5,10,20,30,40,50,70,100,150,200,250,300,400,500,600]
    )

    cb = plt.colorbar(p, ax=ax, orientation="horizontal", pad=0.05)
    cb.set_label('mm', size='x-large')
    
    gl = ax.gridlines(draw_labels=True)
    gl.top_labels = False
    gl.right_labels = False

    ax.set_extent([105, 125, 15, 30]) 
    
    v_time = data.unknown.valid_time.values
    i_time = data.unknown.time.values

    valid_UTC = pd.to_datetime(v_time).strftime('%H:%M UTC %d %b %Y')
    valid_CST = (pd.to_datetime(v_time) + pd.Timedelta(hours=8)).strftime('%H:%M CST %d %b %Y')
    init_UTC = pd.to_datetime(i_time).strftime('%H:%M UTC %d %b %Y')
    init_CST = (pd.to_datetime(i_time) + pd.Timedelta(hours=8)).strftime('%H:%M CST %d %b %Y')

    ax.set_title(f"CWA WRF: 3km resolution\nValid: {valid_UTC} or {valid_CST}\ninitialized at {init_UTC} or {init_CST}\nForecast Hour: {j_val}\n", loc="left")
    ax.set_title("beware of initial runtime and forecast hour", color='red', loc="center")
    ax.set_title("Accumulated Precipitation\n", loc="right")
    
    plt.savefig(img_path, dpi=150)
    plt.close()
    print(f"✅ Saved {j_val}.png")

except Exception as e:
    print(f"❌ Failed to plot {j_val}: {e}")
EOF_PYTHON
done

# ==============================================================================
# 2. RUN SUB-ROUTINE SCRIPTS
# ==============================================================================
echo "⚙️ Executing auxiliary surface mapping matrices..."
./cwa_wrf_surf.sh || echo "⚠️ cwa_wrf_surf.sh failed"
./cwa_wrf_small.sh || echo "⚠️ cwa_wrf_small.sh failed"
./cwa_wrf_6hr.sh || echo "⚠️ cwa_wrf_6hr.sh failed"

# ==============================================================================
# 3. ZERO-CONFLICT COMMIT PIPELINE
# ==============================================================================
echo "⚠️ Collapsing execution logs down to 1 single commit tracking frame..."
git update-ref -d refs/heads/"$BRANCH" 2>/dev/null || true

echo "📦 Packaging current layout structure..."
# Your original Git commit/push logic goes directly here...
