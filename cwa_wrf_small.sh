#!/bin/bash
set -e

echo "--- 執行輔助分析: Regional Accumulated Rain (Small Domain) ---"

SAVE_DIR="./model/CWA/accu_rain_small"
ORIGIN="./accu_rain"

mkdir -p "$SAVE_DIR"

for j in $(seq 0 6 84); do
    i=$(printf "%03d" $j)
    LOCAL_NAME="${i}.grb2"
    IMAGE_PATH="${SAVE_DIR}/${j}.png"

    if [ ! -f "${ORIGIN}/${LOCAL_NAME}" ]; then
        echo "⚠️ Source file ${ORIGIN}/${LOCAL_NAME} not found, skipping..."
        continue
    fi

    export EXP_ORIGIN="${ORIGIN}"
    export EXP_LOCAL_NAME="${LOCAL_NAME}"
    export EXP_IMAGE_PATH="${IMAGE_PATH}"
    export EXP_I_VAL="${i}"
    export EXP_J_VAL="${j}"

    python3 - << 'EOF_PYTHON'
import os
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
import metpy.calc as mpcalc

origin = os.environ['EXP_ORIGIN']
local_name = os.environ['EXP_LOCAL_NAME']
image_path = os.environ['EXP_IMAGE_PATH']
i_val = os.environ['EXP_I_VAL']
j_val = os.environ['EXP_J_VAL']

try:
    data = cfgrib.open_datasets(os.path.join(origin, local_name))
    
    fig = plt.figure(figsize=(10, 10))
    ax = plt.axes(projection=ccrs.PlateCarree())

    ax.add_feature(cfeature.STATES.with_scale('10m'), linewidths=0.5, linestyle='solid', edgecolor='red')
    ax.add_feature(cfeature.BORDERS.with_scale('10m'), linewidths=1.0, linestyle='solid', edgecolor='red')
    ax.add_feature(cfeature.COASTLINE.with_scale('10m'), linewidths=1.0, linestyle='solid', edgecolor='red')
    ax.add_feature(cfeature.LAND.with_scale('10m'), facecolor='#EEEEEE')
    
    p = ax.contourf(
        data[4].longitude,
        data[4].latitude,
        data[4].unknown,
        transform=ccrs.PlateCarree(),
        cmap="gist_ncar",
        extend='max',
        levels=np.arange(0.1, 260, 10)
    )
    
    y = plt.colorbar(p, ax=ax, orientation="horizontal", pad=0.05, cmap='gist_ncar')
    y.set_label('mm', size='x-large')
    
    gl = ax.gridlines(draw_labels=True)
    gl.top_labels = False
    gl.right_labels = False
    
    ax.set_extent([112, 116, 21, 25])
    
    valid_UTC = data[1].t2m.valid_time.dt.strftime('%H:%M UTC %d %b %Y').item()
    valid_CST = (pd.to_datetime(data[1].t2m.valid_time.values + pd.Timedelta(hours=8))).strftime('%H:%M CST/HKT/MST %d %b %Y')
    init_UTC = data[1].t2m.time.dt.strftime('%H:%M UTC %d %b %Y').item()
    init_CST = (pd.to_datetime(data[1].t2m.time.values) + pd.Timedelta(hours=8)).strftime('%H:%M CST/HKT/MST %d %b %Y')
    
    ax.set_title(f"CWA WRF: 3km resolution\nValid: {valid_UTC} or {valid_CST}\ninitialized at {init_UTC} or {init_CST}\nForecast Hour: {i_val}\n", loc="left")
    ax.set_title("beware of initial runtime and forecast hour", color='red', loc="center")
    ax.set_title("accumulated rain\n", loc="right")
    
    plt.savefig(image_path, dpi=150)
    plt.close()
    print(f"✅ Saved {j_val}.png")

except Exception as e:
    print(f"❌ Failed to plot {j_val}: {e}")
EOF_PYTHON

done

echo "--- Regional Accumulated Rain tasks finished ---"