#!/bin/bash
set -e

# ==============================================================================
# INITIAL ENVIRONMENT SETUP
# ==============================================================================
# Prevent the Mac from sleeping as long as this script process is alive


# Expose system paths so background processes can find git, curl, and python
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
export HOME="/Users/eknlau"

echo "=================================================================="
echo "   CWA MESOSCALE DOWNLOAD & ANALYSIS DAEMON (METHOD 2 CALCULATION)"
echo "   Target UTC Hours: 01Z, 07Z, 15Z, 21Z                           "
echo "=================================================================="

# --- RUN ONCE FIRST CONTROLLER ---
RUN_IMMEDIATELY=true

# Infinite loop that calculates the next run time, sleeps, and executes
while true; do
    # Capture current Unix timestamp based strictly on UTC time
    NOW=$(date -u +%s)
    
    # Get current and tomorrow date strings in UTC
    YMD_TODAY=$(date -u +"%Y-%m-%d")
    YMD_TOMORROW=$(date -v+1d -u +"%Y-%m-%d")

    # Define targets explicitly locked to the UTC timezone (-u)
    T1=$(date -u -j -f "%Y-%m-%d %H:%M:%S" "$YMD_TODAY 01:00:00" +%s)
    T2=$(date -u -j -f "%Y-%m-%d %H:%M:%S" "$YMD_TODAY 07:00:00" +%s)
    T3=$(date -u -j -f "%Y-%m-%d %H:%M:%S" "$YMD_TODAY 15:00:00" +%s)
    T4=$(date -u -j -f "%Y-%m-%d %H:%M:%S" "$YMD_TODAY 21:00:00" +%s)

    # If a specific target hour has already passed in UTC, advance it to tomorrow UTC
    [ $NOW -ge $T1 ] && T1=$(date -u -j -f "%Y-%m-%d %H:%M:%S" "$YMD_TOMORROW 01:00:00" +%s)
    [ $NOW -ge $T2 ] && T2=$(date -u -j -f "%Y-%m-%d %H:%M:%S" "$YMD_TOMORROW 07:00:00" +%s)
    [ $NOW -ge $T3 ] && T3=$(date -u -j -f "%Y-%m-%d %H:%M:%S" "$YMD_TOMORROW 15:00:00" +%s)
    [ $NOW -ge $T4 ] && T4=$(date -u -j -f "%Y-%m-%d %H:%M:%S" "$YMD_TOMORROW 21:00:00" +%s)

    # Sort array of upcoming timestamps to find the absolute closest next target
    NEXT_TARGET=$(printf "%s\n" "$T1" "$T2" "$T3" "$T4" | sort -n | head -n1)
    
    # Calculate difference in seconds (guaranteed to be positive now)
    SECONDS_TO_WAIT=$((NEXT_TARGET - NOW))
    
    # Format target date display string for your log
    TARGET_DATE_STRING=$(date -u -r $NEXT_TARGET +"%Y-%m-%d %H:%M:%S UTC")

    # Check if we should execute immediately or sleep
    if [ "$RUN_IMMEDIATELY" = true ]; then
        echo "🚀 [FIRST PASS] Bypassing target wait time to execute immediate pipeline sync..."
        SECONDS_TO_WAIT=0
    else
        echo "⏱️ Waiting $SECONDS_TO_WAIT seconds until the next fixed target: $TARGET_DATE_STRING"
        sleep ${SECONDS_TO_WAIT}s
    fi

    echo "=================================================================="
    echo "   CWA MESOSCALE DOWNLOAD & ANALYSIS DAEMON (RUNNING PIPELINE)   "
    echo "=================================================================="
    echo "--- 任務開始: $(date) (Target Achieved) ---"

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
    git add "$(basename "$0")"
    git add -A

    if [ -d "./model" ]; then git add ./model/*; fi
    if [ -f "./index.html" ]; then git add index.html; fi
    if [ -f "./GHMWS.png" ]; then git add GHMWS.png; fi

    git commit -m "Auto-update: CWA WRF $(date +'%Y-%m-%d %H:%M') [History Cleared]"

    # ==============================================================================
    # 4. REMOTE PUSH AND VS CODE GRAPH SYNC
    # ==============================================================================
    echo "🚀 Streamlining zero-overhead push directly up to GitHub..."
    git push -u origin "$BRANCH" --force

    echo "🔄 Synchronizing VS Code local branch tracking pointers..."
    git update-ref refs/remotes/origin/"$BRANCH" refs/heads/"$BRANCH"

    # ==============================================================================
    # 5. AGGRESSIVE MEMORY PURGE
    # ==============================================================================
    echo "🧹 Purging local object database trails..."
    git reflog expire --expire=now --all
    git gc --prune=now --aggressive 2>/dev/null

    git push origin "$BRANCH" --force
    echo "✅ Execution task finalized seamlessly."

    # Turn off the manual run override flag so subsequent loops calculate true sleep times
    RUN_IMMEDIATELY=false

    # Give a small 2-second breathing room before beginning the next time evaluation calculation
    sleep 2s
done