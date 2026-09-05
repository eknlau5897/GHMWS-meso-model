SAVE_DIR="/Users/eknlau/VS_code/GHMWS-meso-model/model/TJ1HCN/base_reflectivity"
ORIGIN="/Users/eknlau/Desktop/TJ1-CN/latest"
for j in $(seq 6 6 84); do
    i=$(printf "%03d" $j)
    LOCAL_NAME="/Users/eknlau/Desktop/TJ1-CN/latest/SD3.nc"
    IMAGE_PATH="${SAVE_DIR}/${j}.png"

    python3.11 << EOF
import xarray as xr
import numpy as np
import matplotlib.pyplot as plt
import cartopy.crs as ccrs
import cartopy.feature as cfeature
import pandas as pd
import datetime as dt

try:
    init = dt.datetime(2026, 7, 12, 12) 
    data = xr.open_dataset("${LOCAL_NAME}")
    
    fig = plt.figure(figsize=(10,10))
    ax = plt.axes(projection=ccrs.PlateCarree())

    ax.add_feature(cfeature.STATES.with_scale('10m'), linewidths=0.5, edgecolor='red')
    ax.add_feature(cfeature.COASTLINE.with_scale('10m'), linewidths=1.0, edgecolor='red')
    
    p = ax.contourf(data.lon,data.lat,data.base_reflectivity[0],
                    transform=ccrs.PlateCarree(),
                    levels=np.arange(5,70,1),
                    cmap="gist_ncar")

    plt.colorbar(p, ax=ax, orientation="horizontal", pad=0.05).set_label('dBZ', size='large')
    
    gl = ax.gridlines(draw_labels=True)
    gl.top_labels = False
    gl.right_labels = False
    
    ax.set_extent([112,116,21,25])

    # Time handling using pandas for safety
    v_time = pd.to_datetime(data.base_reflectivity.time.values[0])
    valid_UTC = v_time.strftime('%H:%M UTC %d %b %Y')
    init_UTC = init.strftime('%H:%M UTC %d %b %Y')

    ax.set_title(f"TJ-CN: 3km\nValid: {valid_UTC}\nInit: {init_UTC}\nForecast Hour: ${i}\n", loc="left")
    ax.set_title("beware of initial runtime and forecast hour", color='red', loc="center")
    ax.set_title("Base Reflectivity (dBZ)\n", loc="right")
    
    plt.savefig("${IMAGE_PATH}", dpi=150)
    plt.close()
    print("✅ Saved ${j}.png")
    
except Exception as e:
    print(f"Error: {e}")
EOF
done

echo "All tasks finished."
