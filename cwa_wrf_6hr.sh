#!/bin/bash
set -e

echo "--- 執行輔助分析: 10m wind speed, MSLP & past 6 hours precipitation ---"

SAVE_DIR="./model/CWA/6hr_precipitation"
ORIGIN="./accu_rain"

mkdir -p "$SAVE_DIR"

# Loop through forecast hours for 6-hr difference plots
for j in $(seq 0 6 84); do
    i=$(printf "%03d" $j)
    k=$(printf "%03d" $((j+6)))
    
    LOCAL_NAME="${i}.grb2"
    LOCAL_NAME_2="${k}.grb2"
    IMAGE_PATH="${SAVE_DIR}/$((j+6)).png"

    if [ ! -f "${ORIGIN}/${LOCAL_NAME}" ] || [ ! -f "${ORIGIN}/${LOCAL_NAME_2}" ]; then
        echo "⚠️ Source files for hours ${j} or $((j+6)) not found, skipping..."
        continue
    fi

    export EXP_ORIGIN="${ORIGIN}"
    export EXP_LOCAL_NAME="${LOCAL_NAME}"
    export EXP_LOCAL_NAME_2="${LOCAL_NAME_2}"
    export EXP_IMAGE_PATH="${IMAGE_PATH}"
    export EXP_J_VAL="${j}"
    export EXP_K_VAL="${k}"

    python - << 'EOF_PYTHON'
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
local_name_2 = os.environ['EXP_LOCAL_NAME_2']
image_path = os.environ['EXP_IMAGE_PATH']
j_val = os.environ['EXP_J_VAL']
k_val = os.environ['EXP_K_VAL']

try:
    data = cfgrib.open_datasets(os.path.join(origin, local_name))
    data_2 = cfgrib.open_datasets(os.path.join(origin, local_name_2))
    
    fig = plt.figure(figsize=(10, 10))
    ax = plt.axes(projection=ccrs.PlateCarree())

    ax.add_feature(cfeature.STATES.with_scale('10m'), linewidths=0.5, linestyle='solid', edgecolor='k')
    ax.add_feature(cfeature.BORDERS.with_scale('10m'), linewidths=1.0, linestyle='solid', edgecolor='k')
    ax.add_feature(cfeature.COASTLINE.with_scale('10m'), linewidths=1.0, linestyle='solid', edgecolor='k')
    ax.add_feature(cfeature.LAND.with_scale('10m'), facecolor='#EEEEEE')
    
    p = ax.contourf(
        data[4].longitude,
        data[4].latitude,
        data_2[4].unknown - data[4].unknown,
        transform=ccrs.PlateCarree(),
        cmap="gist_ncar",
        extend='max',
        levels=np.arange(0.1, 100.1, 10)
    )
    
    q = ax.contour(
        data_2[3].longitude, data_2[3].latitude, data_2[3].prmsl / 100,
        transform=ccrs.PlateCarree(), colors='k', levels=np.arange(850, 1100, 2)
    )
    plt.clabel(q, fontsize=10, inline=1, inline_spacing=1, fmt='%i', rightside_up=True)
    
    y = plt.colorbar(p, ax=ax, orientation="horizontal", pad=0.05, cmap='gist_ncar')
    y.set_label('mm', size='x-large')
    
    gl = ax.gridlines(draw_labels=True)
    gl.top_labels = False
    gl.right_labels = False
    
    skip = (slice(None, None, 40), slice(None, None, 40))
    ax.barbs(
        data_2[0].longitude[skip], data_2[0].latitude[skip],
        data_2[0].u10[skip] * 3.6 / 1.852, data_2[0].v10[skip] * 3.6 / 1.852,
        barbcolor='red', transform=ccrs.PlateCarree(), flip_barb=False, length=7
    )
    
    ax.set_extent([105, 125, 15, 30])
    
    valid_UTC = data_2[4].unknown.valid_time.dt.strftime('%H:%M UTC %d %b %Y').item()
    valid_CST = (pd.to_datetime(data_2[4].unknown.valid_time.values + pd.Timedelta(hours=8))).strftime('%H:%M CST/HKT/MST %d %b %Y')
    init_UTC = data_2[4].unknown.time.dt.strftime('%H:%M UTC %d %b %Y').item()
    init_CST = (pd.to_datetime(data_2[4].unknown.time.values) + pd.Timedelta(hours=8)).strftime('%H:%M CST/HKT/MST %d %b %Y')
    
    ax.set_title(f"CWA WRF: 3km resolution\nValid: {valid_UTC} or {valid_CST}\ninitialized at {init_UTC} or {init_CST}\nForecast Hour: {k_val}\n", loc="left")
    ax.set_title("beware of initial runtime and forecast hour,may not be up to date", color='red', loc="center")
    ax.set_title("10m wind speed,MSLP and past 6 hours precipitation\n", loc="right")
    
    plt.savefig(image_path, dpi=150)
    plt.close()
    print(f"✅ Saved $((j+6)).png")

except Exception as e:
    print(f"❌ Failed to plot {j_val}: {e}")
EOF_PYTHON

done

# ==============================================================================
# SPECIAL FORECAST HOUR 0 PLOT
# ==============================================================================
echo "--- Plotting Forecast Hour 0 ---"

export EXP_ORIGIN_ZERO="${ORIGIN}"
export EXP_IMAGE_ZERO="${SAVE_DIR}/0.png"

python - << 'EOF_PYTHON_ZERO'
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

origin = os.environ['EXP_ORIGIN_ZERO']
image_path = os.environ['EXP_IMAGE_ZERO']

try:
    data = cfgrib.open_datasets(os.path.join(origin, "000.grb2"))
    
    fig = plt.figure(figsize=(10, 10))
    ax = plt.axes(projection=ccrs.PlateCarree())

    ax.add_feature(cfeature.STATES.with_scale('10m'), linewidths=0.5, linestyle='solid', edgecolor='k')
    ax.add_feature(cfeature.BORDERS.with_scale('10m'), linewidths=1.0, linestyle='solid', edgecolor='k')
    ax.add_feature(cfeature.COASTLINE.with_scale('10m'), linewidths=1.0, linestyle='solid', edgecolor='k')
    ax.add_feature(cfeature.LAND.with_scale('10m'), facecolor='#EEEEEE')
    
    p = ax.contourf(
        data[4].longitude,
        data[4].latitude,
        data[4].unknown,
        transform=ccrs.PlateCarree(),
        cmap="gist_ncar",
        extend='max',
        levels=np.arange(0.1, 100, 10)
    )
    
    q = ax.contour(
        data[3].longitude, data[3].latitude, data[3].prmsl / 100,
        transform=ccrs.PlateCarree(), colors='k', levels=np.arange(850, 1100, 2)
    )
    plt.clabel(q, fontsize=10, inline=1, inline_spacing=1, fmt='%i', rightside_up=True)
    
    y = plt.colorbar(p, ax=ax, orientation="horizontal", pad=0.05, cmap='gist_ncar')
    y.set_label('mm', size='x-large')
    
    gl = ax.gridlines(draw_labels=True)
    gl.top_labels = False
    gl.right_labels = False
    
    skip = (slice(None, None, 40), slice(None, None, 40))
    ax.barbs(
        data[0].longitude[skip], data[0].latitude[skip],
        data[0].u10[skip] * 3.6 / 1.852, data[0].v10[skip] * 3.6 / 1.852,
        barbcolor='red', transform=ccrs.PlateCarree(), flip_barb=False, length=7
    )
    
    ax.set_extent([105, 125, 15, 30])
    
    valid_UTC = data[4].unknown.valid_time.dt.strftime('%H:%M UTC %d %b %Y').item()
    valid_CST = (pd.to_datetime(data[4].unknown.valid_time.values + pd.Timedelta(hours=8))).strftime('%H:%M CST/HKT/MST %d %b %Y')
    init_UTC = data[4].unknown.time.dt.strftime('%H:%M UTC %d %b %Y').item()
    init_CST = (pd.to_datetime(data[4].unknown.time.values) + pd.Timedelta(hours=8)).strftime('%H:%M CST/HKT/MST %d %b %Y')
    
    ax.set_title(f"CWA WRF: 3km resolution\nValid: {valid_UTC} or {valid_CST}\ninitialized at {init_UTC} or {init_CST}\nForecast Hour: 0\n", loc="left")
    ax.set_title("wind speed,MSLP and past 6 hours precipitation\n", loc="right")
    ax.set_title("beware of initial runtime and forecast hour", color='red', loc="center")
    
    plt.savefig(image_path, dpi=150)
    plt.close()
    print("✅ Saved 0.png")

except Exception as e:
    print(f"❌ Failed to plot 0: {e}")
EOF_PYTHON_ZERO

echo "--- All 6-hour precipitation tasks finished ---"