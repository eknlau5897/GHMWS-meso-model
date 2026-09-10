#!/bin/bash

# ==============================================================================
# MAIN DEPLOYMENT WORKFLOW FUNCTION
# ==============================================================================
run_pipeline() {
    # Treat non-zero exit codes within the task block as warnings rather than crashing the loop
    (
        set -e

        # ==============================================================================
        # INITIAL ENVIRONMENT SETUP
        # ==============================================================================
        export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
        export HOME="/Users/eknlau"

        echo "=================================================================="
        echo "   CWA MESOSCALE DOWNLOAD & ANALYSIS DAEMON                      "
        echo "   Triggered via Continuous UTC Scheduler                         "
        echo "=================================================================="

        echo "=================================================================="
        echo "   CWA MESOSCALE DOWNLOAD & ANALYSIS DAEMON (RUNNING PIPELINE)   "
        echo "=================================================================="
        echo "--- 任務開始: $(date -u) UTC ---"

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

            # Pause 5 seconds after processing each forecast hour
            echo "⏳ Pausing 5 seconds before next forecast hour..."
            sleep 120
        done

        # ==============================================================================
        # 2. RUN SUB-ROUTINE SCRIPTS
        # ==============================================================================
        echo "⚙️ Executing auxiliary surface mapping matrices..."
        ./cwa_wrf_surf.sh || echo "⚠️ cwa_wrf_surf.sh failed"
        ./cwa_wrf_small.sh || echo "⚠️ cwa_wrf_small.sh failed"
        ./cwa_wrf_6hr.sh || echo "⚠️ cwa_wrf_6hr.sh failed"

        # ==============================================================================
        # 3. ZERO-CONFLICT COMMIT PIPELINE & HISTORY WIPE
        # ==============================================================================
        echo "⚠️ Collapsing commit history to keep repo light..."
        
        git checkout --orphan temp_branch
        git add -A
        git commit -m "Auto-update CWA mesoscale plots: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

        git branch -D "$BRANCH" 2>/dev/null || true
        git branch -m "$BRANCH"

        echo "🚀 Force pushing fresh state to remote..."
        git push -f origin "$BRANCH"
        
        echo "--- 任務完成: $(date -u) UTC ---"
    ) || echo "⚠️ Pipeline execution encountered an error, but daemon will remain active."
}

# ==============================================================================
# SCHEDULER MATRIX & DAEMON CONTROL
# ==============================================================================
TARGET_HOURS=(1 7 13 19)

get_seconds_until_next_run() {
    local now_epoch
    now_epoch=$(date -u +%s)
    local min_sleep=-1

    for hour in "${TARGET_HOURS[@]}"; do
        local formatted_hour
        formatted_hour=$(printf "%02d" "$hour")

        local target_epoch
        target_epoch=$(date -u -d "today ${formatted_hour}:00:00" +%s 2>/dev/null || date -u -j -f "%Y-%m-%d %H:%M:%S" "$(date -u +%Y-%m-%d) ${formatted_hour}:00:00" +%s)

        if (( target_epoch <= now_epoch )); then
            target_epoch=$(date -u -d "tomorrow ${formatted_hour}:00:00" +%s 2>/dev/null || date -u -j -f "%Y-%m-%d %H:%M:%S" "$(date -u -v+1d +%Y-%m-%d) ${formatted_hour}:00:00" +%s)
        fi

        local diff=$(( target_epoch - now_epoch ))

        if (( min_sleep == -1 || diff < min_sleep )); then
            min_sleep=$diff
        fi
    done

    echo "$min_sleep"
}

# Execute pipeline immediately on initial script launch
run_pipeline

# Infinite loop with dynamic target sleep calculation
while true; do
    sleep_seconds=$(get_seconds_until_next_run)

    echo "💤 [Daemon] Sleeping for ${sleep_seconds}s (approx $(( sleep_seconds / 3600 ))h $(( (sleep_seconds % 3600) / 60 ))m)... Next run at target UTC schedule."
    sleep "$sleep_seconds"

    run_pipeline
done