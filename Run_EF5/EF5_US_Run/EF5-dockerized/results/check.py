import pandas as pd

df = pd.read_csv('ts.03404900.crest.csv')
print(df.head(10))
print('---')
print(df.columns.tolist())


