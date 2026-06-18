import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

df = pd.read_csv('ts.03404900.crest.csv')
df['Time'] = pd.to_datetime(df['Time'])

fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 8))

ax1.plot(df['Time'], df['Discharge(m^3 s^-1)'], color='blue')
ax1.set_ylabel('Discharge (m3/s)')
ax1.set_title('EF5 CREST - Gauge 03404900 - Kentucky July 28 2022')
ax1.grid(True)

ax2.bar(df['Time'], df['Precip(mm h^-1)'], color='gray', width=0.001)
ax2.set_ylabel('Rainfall (mm/h)')
ax2.set_xlabel('Time')
ax2.invert_yaxis()
ax2.grid(True)

plt.tight_layout()
plt.savefig('hydrograph.png', dpi=150)
print('saved hydrograph.png')
