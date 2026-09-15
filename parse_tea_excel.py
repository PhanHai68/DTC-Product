import pandas as pd
import json

excel_path = r'D:\Flutter_Project\DTCproduct\docs\1 Máy tách màu\DTCProduct_Database_May_Tach_Mau_Tra_DF.xlsx'
df = pd.read_excel(excel_path)
print(df.head())
records = df.to_dict(orient='records')
print(json.dumps(records, ensure_ascii=False, indent=2))
