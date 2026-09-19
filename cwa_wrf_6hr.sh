URL="https://cwaopendata.s3.ap-northeast-1.amazonaws.com/Model"
PREFIX="M-A0064"
SAVE_DIR="/Users/eknlau/VS_code/GHMWS-meso-model/model/CWA/6hr_precipitation/"
ORIGIN="/Users/eknlau/Desktop/CWA/accu_rain"
for j in $(seq 0 6 78); do
    i=$(printf "%03d" $j)
    k=$(printf "%03d" $((j+6)))
    SOURCE_FILE="${PREFIX}-${i}.grb2"
    LOCAL_NAME="${i}.grb2"
    LOCAL_NAME_2="${k}.grb2"
    FILE_PATH="${SAVE_DIR}/${LOCAL_NAME}"
    IMAGE_PATH="${SAVE_DIR}/$((j+6)).png"

    # Run Python Plotting
    /opt/anaconda3/bin/python << EOF
import xarray as xr
import numpy as np
import matplotlib.pyplot as plt
import cartopy.crs as ccrs
import cartopy.feature as cfeature
import cfgrib
import pandas as pd

try:
    # Open dataset
    data=cfgrib.open_datasets("${ORIGIN}/${LOCAL_NAME}")
    data_2=cfgrib.open_datasets("${ORIGIN}/${LOCAL_NAME_2}")
    fig = plt.figure(figsize=(10,10))
    ax = plt.axes(projection=ccrs.PlateCarree())

    ax.add_feature(cfeature.STATES.with_scale('10m'), linewidths=0.5, linestyle='solid', edgecolor='k')
    ax.add_feature(cfeature.BORDERS.with_scale('10m'), linewidths=1.0, linestyle='solid', edgecolor='k')
    ax.add_feature(cfeature.COASTLINE.with_scale('10m'), linewidths=1.0, linestyle='solid', edgecolor='k')
    ax.add_feature(cfeature.LAND.with_scale('10m'),facecolor='#EEEEEE')
    p = ax.contourf(
        data[4].longitude,
        data[4].latitude,
        data_2[4].unknown-data[4].unknown,
        transform=ccrs.PlateCarree(),
        cmap="gist_ncar",
        extend='max',
        levels=np.arange(0.1,100.1,10)
    )
    q=ax.contour(data_2[3].longitude,data_2[3].latitude,data_2[3].prmsl/100,transform=ccrs.PlateCarree(),colors='k',levels=np.arange(850,1100,2))
    plt.clabel(q,fontsize=10, inline=1, inline_spacing=1, fmt='%i', rightside_up=True)
    y=plt.colorbar(p, ax=ax, orientation="horizontal", pad=0.05, cmap='gist_ncar')
    y.set_label('mm',size='x-large')
    gl=ax.gridlines(draw_labels=True)
    gl.xlabels_top = False
    gl.ylabels_left = False
    skip = (slice(None, None, 40), slice(None, None, 40))
    ax.barbs(data_2[0].longitude[skip],data_2[0].latitude[skip],data_2[0].u10[skip]*3.6/1.852,data_2[0].v10[skip]*3.6/1.852,barbcolor='red',transform=ccrs.PlateCarree(),flip_barb=False,length=7)
    
    ax.set_extent([105,125,15,30])
    valid_UTC = data_2[4].unknown.valid_time.dt.strftime('%H:%M UTC %d %b %Y').item()
    valid_CST=(pd.to_datetime(data_2[4].unknown.valid_time.values+pd.Timedelta(hours=8))).strftime('%H:%M CST/HKT/MST %d %b %Y')
    init_UTC = data_2[4].unknown.time.dt.strftime('%H:%M UTC %d %b %Y').item()
    init_CST = (pd.to_datetime(data_2[4].unknown.time.values) + pd.Timedelta(hours=8)).strftime('%H:%M CST/HKT/MST %d %b %Y')
    ax.set_title(f"CWA WRF: 3km resolution\nValid: {valid_UTC} or {valid_CST}\ninitialized at {init_UTC} or {init_CST}\nForecast Hour: ${k}\n", loc="left")
    ax.set_title("beware of initial runtime and forecast hour,may not be up to date", color='red', loc="center")
    ax.set_title("10m wind speed,MSLP and past 6 hours precipitation\n", loc="right")
    plt.savefig("$IMAGE_PATH", dpi=150)
    plt.close()
    print("✅ Saved $((j+6)).png")

except Exception as e:
    print(f"❌ Failed to plot ${j}: {e}")
EOF

done

python3.11 << EOF
import xarray as xr
import numpy as np
import matplotlib.pyplot as plt
import cartopy.crs as ccrs
import cartopy.feature as cfeature
import cfgrib
import pandas as pd

try:
    # Open dataset
    data=cfgrib.open_datasets("/Users/eknlau/Desktop/CWA/accu_rain/000.grb2")
    fig = plt.figure(figsize=(10,10))
    ax = plt.axes(projection=ccrs.PlateCarree())

    ax.add_feature(cfeature.STATES.with_scale('10m'), linewidths=0.5, linestyle='solid', edgecolor='k')
    ax.add_feature(cfeature.BORDERS.with_scale('10m'), linewidths=1.0, linestyle='solid', edgecolor='k')
    ax.add_feature(cfeature.COASTLINE.with_scale('10m'), linewidths=1.0, linestyle='solid', edgecolor='k')
    ax.add_feature(cfeature.LAND.with_scale('10m'),facecolor='#EEEEEE')
    p = ax.contourf(
        data[4].longitude,
        data[4].latitude,
        data[4].unknown,
        transform=ccrs.PlateCarree(),
        cmap="gist_ncar",
        extend='max',
        levels=np.arange(0.1,100,10)
    )
    q=ax.contour(data[3].longitude,data[3].latitude,data[3].prmsl/100,transform=ccrs.PlateCarree(),colors='k',levels=np.arange(850,1100,2))
    plt.clabel(q,fontsize=10, inline=1, inline_spacing=1, fmt='%i', rightside_up=True)
    y=plt.colorbar(p, ax=ax, orientation="horizontal", pad=0.05, cmap='gist_ncar')
    y.set_label('mm',size='x-large')
    gl=ax.gridlines(draw_labels=True)
    gl.xlabels_top = False
    gl.ylabels_left = False
    skip = (slice(None, None, 40), slice(None, None, 40))
    ax.barbs(data[0].longitude[skip],data[0].latitude[skip],data[0].u10[skip]*3.6/1.852,data[0].v10[skip]*3.6/1.852,barbcolor='red',transform=ccrs.PlateCarree(),flip_barb=False,length=7)
    
    ax.set_extent([105,125,15,30])
    valid_UTC = data[4].unknown.valid_time.dt.strftime('%H:%M UTC %d %b %Y').item()
    valid_CST=(pd.to_datetime(data[4].unknown.valid_time.values+pd.Timedelta(hours=8))).strftime('%H:%M CST/HKT/MST %d %b %Y')
    init_UTC = data[4].unknown.time.dt.strftime('%H:%M UTC %d %b %Y').item()
    init_CST = (pd.to_datetime(data[4].unknown.time.values) + pd.Timedelta(hours=8)).strftime('%H:%M CST/HKT/MST %d %b %Y')
    ax.set_title(f"CWA WRF: 3km resolution\nValid: {valid_UTC} or {valid_CST}\ninitialized at {init_UTC} or {init_CST}\nForecast Hour: 0\n", loc="left")
    ax.set_title("wind speed,MSLP and past 6 hours precipitation\n", loc="right")
    ax.set_title("beware of initial runtime and forecast hour", color='red', loc="center")
    plt.savefig("/Users/eknlau/VS_code/GHMWS-meso-model/model/CWA/6hr_precipitation/0.png", dpi=150)
    plt.close()
    print("✅ Saved 0.png")
except Exception as e:
    print(f"❌ Failed to plot 0: {e}")
EOF

echo "All tasks finished."